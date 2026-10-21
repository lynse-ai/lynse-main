/// Xyrix 适配器（方案 A）：基于 flutter_blue_plus 在 Dart 层直实现 Xyrix BLE 协议。
///
/// 协议要点（XyrixSDK-2 文档 + 2026-09~10 真机联调实测）：
/// - 服务/特征：Nordic UART（写 6e400002…，通知 6e400003…）
/// - 帧格式：`FF 55 AA [len=N][cmd][data]`（长度字节 = 数据长度，帧总长 5+N）
/// - 设备身份：广播 manufacturerData（companyId 0xABCD）载荷即 ASCII SN
/// - 文件列表：`FF 55 AA 00 05` 起始帧 + 明文行（`路径 -字节 B -秒 s`）+ `FF 55 AA 00 2F` 结束帧
/// - 电量 0x01→`[level, charging]`；版本 0x17→`"日期 v2.0.13"`；
///   存储 0x2E→`[总KB][剩余KB]`（均大端，2026-10-05 实测）
/// - 录音类命令（0x1B/0x1C/0x1F/0x50/0x52/0x53/0x32-0x35）**无回执帧**，
///   写入即生效；只有 0x1D/0x13 等回 `2F` ACK
///
/// 仍未确认（不要在代码里猜，用 xyrix_probe.dart 打真机取证）：
/// 1. 0x54 数据包尾部 2 字节 CRC 的多项式/初值（当前只按序列号连续性判丢包）
/// 2. 文件传输 0x07 之后的数据分包是否有帧头（现为「通知边界即数据边界」原样落盘）
/// 3. 热点 SSID/密码的下发途径——0x21 只回状态字节 `01`，不带凭证（实测）
/// 4. 精确匹配 Xyrix 的广播特征（现在只要求「有名字 + 有厂商数据」）
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dting/config/config.dart';
import 'package:dting/core/hardware/ble_device_adapter.dart';
import 'package:dting/core/hardware/hardware_event.dart';
import 'package:dting/core/hardware/models.dart';
import 'package:dting/core/hardware/transfer_target.dart';
import 'package:dting/core/hardware/xyrix/hotspot_connector.dart';
import 'package:dting/core/hardware/xyrix/xyrix_commands.dart';
import 'package:dting/core/hardware/xyrix/xyrix_frame_codec.dart';
import 'package:dting/core/hardware/xyrix/xyrix_opus_muxer.dart';
import 'package:dting/core/hardware/xyrix/xyrix_probe.dart';
import 'package:dting/core/hardware/xyrix/xyrix_stream_parsers.dart';
import 'package:dting/core/hardware/xyrix/xyrix_wifi_transfer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';

class XyrixAdapter extends BleDeviceAdapter implements XyrixProbeHost {
  final StreamController<HardwareEvent> _events =
      StreamController<HardwareEvent>.broadcast();

  /// 探测台等待响应帧的挂起请求（见 [awaitResponse]）
  final List<_FrameWaiter> _waiters = [];

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;

  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  StreamSubscription? _notifySub;

  /// 实时推流捕获：连接期间设备推送的所有原始字节（录音音频流 +
  /// 控制响应帧）完整落盘，供协议分析与后续音频解码
  IOSink? _streamSink;
  File? _streamFile;

  /// 文件列表收集 + 实时音频流解析（纯逻辑，见 xyrix_stream_parsers.dart）
  late final XyrixStreamRouter _router = XyrixStreamRouter(
    onFrame: _dispatchFrame,
    onFileList: _onFileListParsed,
    onOpusPacket: _onOpusPacket,
  );
  Completer<List<RecordingFile>>? _fileListCompleter;
  List<RecordingFile> _lastFileList = const [];

  /// 录音停止后的列表轮询重试（设备保存 WAV 耗时随录音时长增长）
  Timer? _listRefreshTimer;
  int _listRefreshAttempt = 0;
  int _listRefreshBaseCount = 0;

  /// 实时音频流（0x54 OPUS 推送）本地落盘状态
  IOSink? _rtSink;
  File? _rtFile;
  File? _rtOggFile;
  IOSink? _rtOggSink;
  XyrixChunkAccumulator? _rtAccumulator;
  XyrixOpusMuxer? _rtMuxer;
  int _rtPayloadBytes = 0;
  int _rtPackets = 0;
  Timer? _rtIdleTimer;

  /// 捕获文件是异步打开的，打开期间的包先入队——否则首包必丢
  final List<XyrixOpusPacket> _rtQueue = [];
  bool _rtOpening = false;

  /// 包连续性：设备给的 4 字节序列号用于判定丢包/乱序（数据完整性判据）
  int? _rtLastSeq;
  int _rtSeqGaps = 0;
  int _rtOutOfOrder = 0;

  /// BLE 文件下载状态机：0x07 准备 + 0x08 启动后设备持续推送文件数据，
  /// 数据包分帧格式厂商文档未给出（联调中按原始字节落盘 + 计数推进度）。
  ///
  /// 完成判定以**设备 0x2D 应答确认的大小**为准（比列表里的 sizeBytes 更贴近
  /// 真实内容）；两者不一致时记日志并采用设备值。协议无字节偏移能力，
  /// BLE 通道不做续传，每次从头重传。
  bool _downloading = false;
  IOSink? _dlSink;
  TransferTarget? _dlTarget;
  RecordingFile? _dlSource;
  int _dlReceived = 0;

  /// 权威期望字节数：0x2D 确认值优先，未确认时用列表上报值
  int _dlExpectedBytes = 0;

  /// 文件列表上报值，仅用于与设备确认值对账
  int _dlListBytes = 0;
  bool _dlFirstPacketLogged = false;
  DateTime _dlStartTime = DateTime.now();
  DateTime _dlLastProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _dlStallTimer;
  Timer? _dlPrepareTimer;
  Completer<void>? _dlCompleter;

  /// 下载两阶段：true = 已发 0x07 等设备 0x2D 应答（通知走路由器）；
  /// false+downloading = 数据阶段（通知原样写入目标文件）
  bool _dlAwaitingReady = false;

  /// Nordic UART Service
  static final Guid _serviceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid _writeUuid = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid _notifyUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

  @override
  String get vendorId => HardwareVendor.xyrix;

  @override
  String get vendorDisplayName => 'Xyrix';

  @override
  CapabilityManifest get capabilities => const CapabilityManifest({
    HardwareCapability.deleteFile,
    // addMark 不声明：命令表里没有打标命令（0x30 只在注释里被称作「预留」，
    // 真机上未确认），声明了就是让 UI 显示一个必然抛异常的按钮
    // firmwareUpgrade：无独立 OTA API，走文件传输通道，暂不开放
    // wifiTransfer 暂不声明：2026-10-05 真机实测 0x21 只回状态字节
    // `FF 55 AA 01 21 01`、不回传 SSID/密码，且之后手机连扫 25s 不见新 AP，
    // 0x11 四种载荷编码均无回执——凭证来源需厂商确认。
    // 链路代码与 Android 原生 dting/hotspot 通道都已就位，拿到规则即可打开声明；
    // 现在声明出去，UI 就会摆一个必然失败的「快传」按钮
    HardwareCapability.pauseResume,
    HardwareCapability.liveAudio,
  });

  /// 音频外传快传会话（WiFi 热点 + TCP），同一时刻至多一个
  XyrixWifiTransferSession? _wifiTransfer;

  /// 最近一次快传会话，跑完不清空——探测台要在 run() 返回后读它的结论
  XyrixWifiTransferSession? _lastWifiSession;
  final HotspotConnector _hotspotConnector = MethodChannelHotspotConnector();

  @override
  Stream<HardwareEvent> get events => _events.stream;

  void _emit(HardwareEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  // ------------------------------------------------------------------
  // 扫描
  // ------------------------------------------------------------------

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            throw HardwareException(HardwareErrorCode.unknown, '蓝牙未开启');
          },
        );
    _emit(const ScanStateEvent(true));
    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final device = _toDiscovered(r);
        if (device != null) {
          _emit(DeviceDiscoveredEvent(device));
        }
      }
    });
    await FlutterBluePlus.startScan(timeout: timeout, continuousUpdates: true);
    FlutterBluePlus.isScanning.where((s) => !s).first.then((_) {
      _emit(const ScanStateEvent(false));
    });
  }

  /// 过滤规则：有名称 + 有厂商数据。
  /// TODO(厂商确认)：按 manufacturerData 中的 SN/广播特征精确匹配 Xyrix 设备。
  DiscoveredDevice? _toDiscovered(ScanResult r) {
    final name =
        r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;
    if (name.isEmpty) return null;
    final mfg = r.advertisementData.manufacturerData;
    if (mfg.isEmpty) return null;
    final bytes = <int>[];
    mfg.forEach((_, v) => bytes.addAll(v));
    return DiscoveredDevice(
      vendorId: vendorId,
      deviceId: r.device.remoteId.str,
      name: name,
      rssi: r.rssi,
      manufacturerData: bytes,
    );
  }

  /// 从厂商数据解析 SN：companyId 0xABCD 的载荷即 ASCII SN
  /// （真机实测广播载荷 `32 36 30 …` = "2606260101400084"）
  String? parseSerialNumber(DiscoveredDevice d) {
    if (d.manufacturerData.isEmpty) return null;
    final text = ascii.decode(d.manufacturerData, allowInvalid: true);
    final sn = text.replaceAll(RegExp(r'[^!-~]'), '');
    return sn.isEmpty ? null : sn;
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    _emit(const ScanStateEvent(false));
  }

  // ------------------------------------------------------------------
  // 连接
  // ------------------------------------------------------------------

  @override
  Future<void> connect(DiscoveredDevice device, {String? authKey}) async {
    // 重连可能发生在同一适配器实例上：清掉上一次会话残留的接收缓冲/
    // 文件列表收集状态，避免旧字节污染新链路的解析
    _resetFileListState();
    _emit(ConnectionStateEvent(device.deviceId, ConnectionPhase.connecting));
    final dev = BluetoothDevice.fromId(device.deviceId);
    _device = dev;
    _connectedName = device.name;
    await _connSub?.cancel();
    _connSub = dev.connectionState.listen((state) {
      // 只负责掉线检测；connected 由 connect() 流程在服务发现完成后发布，
      // 避免 GATT 链路刚建立（服务/通知均未就绪）就把 UI 置为「已连接」。
      switch (state) {
        case BluetoothConnectionState.disconnected:
          _writeChar = null;
          // 掉线必须就地终止传输：否则 downloadFile() 的 future 会一直挂到
          // 15s 断流看门狗，期间 UI 停在「传输中」且断点无人收尾
          if (_downloading) {
            _finishDownload(
              TransferState.failed,
              stopIntent: TransferStopIntent.interrupted,
              reason: '蓝牙连接中断（已收 $_dlReceived/$_dlExpectedBytes 字节）',
            );
          }
          _emit(
            ConnectionStateEvent(device.deviceId, ConnectionPhase.disconnected),
          );
          break;
        default:
          break;
      }
    });
    try {
      await dev.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 15),
      );
      // MTU 协商：SDK 文档 connect() 明确「连接成功后自动执行 MTU 协商（Android），
      // 默认请求 512」。我们此前从不请求，批量下发可能被小 MTU 卡住
      if (Platform.isAndroid) {
        try {
          final negotiated = await dev.requestMtu(512);
          debugPrint('[Xyrix] MTU 协商：请求 512 → $negotiated');
        } catch (e) {
          debugPrint('[Xyrix] MTU 协商失败（继续用默认值）: $e');
        }
      }
      debugPrint('[Xyrix] GATT 链路已建立，开始服务发现');
      final services = await dev.discoverServices();
      debugPrint(
        '[Xyrix] 发现 ${services.length} 个服务: '
        '${services.map((s) => s.uuid.str).join(', ')}',
      );
      for (final service in services) {
        if (service.uuid != _serviceUuid) continue;
        for (final c in service.characteristics) {
          if (c.uuid == _writeUuid) {
            _writeChar = c;
          } else if (c.uuid == _notifyUuid) {
            await c.setNotifyValue(true);
            await _notifySub?.cancel();
            _notifySub = c.onValueReceived.listen(_onNotifyData);
          }
        }
      }
      if (_writeChar == null) {
        throw HardwareException(
          HardwareErrorCode.connectionLost,
          '未找到 Nordic UART 写特征（需厂商配置 characteristicMatcher）',
        );
      }
      // 连接后同步时间，保证设备录音文件时间戳正确
      await sendCommand(
        XyrixCommands.syncTime,
        XyrixFrameCodec.timeData(DateTime.now()),
      );
      // 全部就绪后开启推流捕获（原始字节完整落盘），再发布 connected/ready
      await _openStreamCapture();
      debugPrint('[Xyrix] UART 就绪（write/notify 已订阅），时间已同步');
      // SN 直接取自广播厂商数据（0xFF 设备号命令此版固件无响应，联调实测）
      final sn = parseSerialNumber(device);
      if (sn != null) {
        _emit(DeviceInfoEvent(DeviceHardwareInfo(serialNumber: sn)));
      }
      _emit(ConnectionStateEvent(device.deviceId, ConnectionPhase.connected));
      _emit(ConnectionStateEvent(device.deviceId, ConnectionPhase.ready));
      // 连接即拉取一次设备文件列表：不做这步，用户必须手动点刷新才能看到
      // 设备内已有录音（录音停止后的自动刷新只覆盖本次新录音）
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (_writeChar == null || _downloading) return;
        listFiles()
            .then((files) {
              debugPrint('[Xyrix] 连接后拉取文件列表：${files.length} 个文件');
            })
            .catchError((_) {});
      });
      _maybeStartSelfTest();
      _maybeStartProbe();
    } on HardwareException {
      await _abortConnection(dev);
      rethrow;
    } catch (e) {
      await _abortConnection(dev);
      throw HardwareException(HardwareErrorCode.connectionLost, '$e');
    }
  }

  /// 连接流程中途失败：清理链路与状态，避免 UI 卡在「已连接」
  Future<void> _abortConnection(BluetoothDevice dev) async {
    try {
      await dev.disconnect();
    } catch (_) {}
    _writeChar = null;
    _resetFileListState();
    await _closeRealtimeCapture();
    await _closeStreamCapture();
    _emit(ConnectionStateEvent(dev.remoteId.str, ConnectionPhase.disconnected));
  }

  /// 丢弃进行中的文件列表收集（断连/超时时调用）
  void _resetFileListState() {
    _router.reset();
    // 上一会话排队的音频包不能带进新链路，否则会写进新文件污染内容
    _rtQueue.clear();
    final completer = _fileListCompleter;
    _fileListCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(_lastFileList);
    }
  }

  /// 打开推流捕获文件（连接成功后调用）
  Future<void> _openStreamCapture() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      _streamFile = File('${dir.path}/xyrix_stream_$ts.bin');
      _streamSink = _streamFile!.openWrite(mode: FileMode.append);
      debugPrint('[Xyrix] 推流捕获: ${_streamFile!.path}');
    } catch (e) {
      debugPrint('[Xyrix] 打开推流捕获失败: $e');
    }
  }

  /// 关闭推流捕获文件
  Future<void> _closeStreamCapture() async {
    try {
      await _streamSink?.flush();
      await _streamSink?.close();
    } catch (_) {}
    _streamSink = null;
    _streamFile = null;
  }

  @override
  Future<void> disconnect() async {
    // 掉线属于意外中断：断点保留，下次下载可从 0 重传（WiFi 通道可续传）
    if (_downloading) {
      await _finishDownload(
        TransferState.failed,
        stopIntent: TransferStopIntent.interrupted,
      );
    }
    await _wifiTransfer?.abort();
    _listRefreshTimer?.cancel();
    await _closeRealtimeCapture();
    await _notifySub?.cancel();
    _notifySub = null;
    await _device?.disconnect();
    _device = null;
    _writeChar = null;
    _resetFileListState();
    await _closeStreamCapture();
  }

  // ------------------------------------------------------------------
  // 命令收发
  // ------------------------------------------------------------------

  Future<void> sendCommand(int command, [List<int> data = const []]) async {
    final char = _writeChar;
    if (char == null) {
      throw HardwareException(HardwareErrorCode.connectionLost, '设备未连接');
    }
    debugPrint(
      '[Xyrix] 发送命令 '
      '0x${command.toRadixString(16).padLeft(2, '0')} '
      'data=${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
    );
    await char.write(XyrixFrameCodec.encode(command, data));
  }

  /// 探测台专用：非空时，每条 GATT 通知的原始字节额外旁路一份进来。
  /// 文本协议（厂商 AAR 里的 `*DEV#…`）不是 FF55AA 帧，帧解析器会直接丢掉，
  /// 只能用这种方式接。
  List<List<int>>? rawTap;

  /// 探测台专用：绕过 FF55AA 帧封装，直接写原始字节。
  Future<void> sendRaw(List<int> bytes) async {
    final char = _writeChar;
    if (char == null) {
      throw HardwareException(HardwareErrorCode.connectionLost, '设备未连接');
    }
    debugPrint('[Xyrix] 原始写入 ${bytes.length}B ${utf8.decode(bytes, allowMalformed: true)}');
    await char.write(bytes);
  }

  /// 一次性核对「这张 XYRI 卡会不会其实讲厂商 AAR（com.nveasy.ble）那套文本命令」。
  ///
  /// 值得查的理由是实的：XyrixSDK-2 交付包里的 AAR 就是 `com.nveasy.ble`，
  /// 它的命令语言是 `*APP#<cmd>#<arg…>#`（回包前缀 `*DEV#`），而
  /// `*APP#wifi#<n>#`、`*APP#opusfile#<n>#` 正好对应目标里卡住的两项
  /// （WiFi 快传、opus 载荷）。如果本卡认这套文本，规则就有厂商代码可依，
  /// 不用再靠穷举猜。工厂类命令（`format`/`blename`/`devpair`/`sdkkey`/
  /// `authsn`/`algkey`）一律不发：写错是不可恢复的出厂信息破坏。
  @override
  Future<String> runTextCommandProbe() async {
    const names = ['version', 'battery', 'mem', 'getlist', 'wifi#1', 'wifi#0'];
    final heard = <String>[];
    for (final name in names) {
      final tap = <List<int>>[];
      rawTap = tap;
      try {
        await sendRaw(utf8.encode('*APP#$name#'));
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        if (tap.isEmpty) {
          heard.add('$name:无回包');
        } else {
          final all = tap.expand((e) => e).toList();
          final text = utf8.decode(all, allowMalformed: true).replaceAll('\n', '\\n');
          heard.add(
            '$name:${all.length}B「${text.length <= 40 ? text : '${text.substring(0, 40)}…'}」',
          );
        }
      } catch (e) {
        heard.add('$name:写失败($e)');
      } finally {
        rawTap = null;
      }
    }
    return heard.join(' | ');
  }

  // ------------------------------------------------------------------
  // XyrixProbeHost（探测台，见 xyrix_probe.dart）
  // ------------------------------------------------------------------

  /// 探测台：登记等待方 → 写命令 → 等响应帧。顺序不可颠倒，
  /// 否则设备 100ms 内的回帧会被常规业务分发吃掉、探测台误报无响应。
  @override
  Future<XyrixFrame?> exchange(
    int command,
    List<int> data, {
    int? expect,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final waiter = _FrameWaiter({expect ?? command, XyrixCommands.commandAck});
    _waiters.add(waiter);
    try {
      await sendCommand(command, data);
      return await waiter.completer.future.timeout(
        timeout,
        onTimeout: () => null,
      );
    } finally {
      _waiters.remove(waiter);
    }
  }

  @override
  void log(String line) => debugPrint('[Xyrix] $line');

  /// 每个解析出的帧先给挂起的等待方，再走常规业务分发
  void _resolveWaiters(XyrixFrame frame) {
    if (_waiters.isEmpty) return;
    for (final waiter in _waiters.toList()) {
      if (waiter.commands.contains(frame.command)) {
        _waiters.remove(waiter);
        if (!waiter.completer.isCompleted) {
          waiter.completer.complete(frame);
        }
      }
    }
  }

  void _onNotifyData(List<int> value) {
    // 0) 探测台的原始旁路（文本协议不走帧解析器）
    rawTap?.add(value);
    // 1) 原始字节无条件落盘（推流音频 + 控制响应都保住）
    _streamSink?.add(value);
    // 2b) 增量拆容器 → 完整 Opus 包（含 0x48 TOC）→ Ogg，产出**能播放**的 .opus
    final accumulator = _rtAccumulator;
    final muxer = _rtMuxer;
    if (accumulator != null && muxer != null) {
      try {
        final bytes = value is Uint8List ? value : Uint8List.fromList(value);
        for (final packet in accumulator.addData(bytes)) {
          muxer.writePacket(packet);
        }
      } catch (e) {
        debugPrint('[Xyrix] 实时打包失败（原始 .raw 仍在）: $e');
      }
    }
    // 2) 控制帧打全量 hex 便于对照厂商文档；大块数据只打长度。
    //    488B 的音频/文件块每 1.8s 就有一千多条，逐条转 hex 会把 UI 线程压满，
    //    反过来拖慢 notify 消费甚至丢包——首包 hex 已由 _onDownloadBytes 记录。
    if (value.length <= 32) {
      debugPrint(
        '[Xyrix] 收到通知 ${value.length}B: '
        '${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
    } else {
      debugPrint('[Xyrix] 收到数据块 ${value.length}B');
    }
    // 3) 下载数据阶段：字节全部计入目标文件（分帧格式未知，先原样落盘），
    //    控制帧解析暂停——随机数据可能碰巧命中命令码，干扰 UI 状态
    if (_downloading && !_dlAwaitingReady) {
      _onDownloadBytes(value);
      return;
    }
    // 4) 命令帧 / 文件列表 / 实时音频流统一由路由器分发
    _router.feed(value);
  }

  /// 文件列表解析完成：发布事件并唤醒 listFiles() 等待方
  void _onFileListParsed(List<RecordingFile> files) {
    debugPrint('[Xyrix] 文件列表解析完成：${files.length} 个文件');
    if (Config.selfTestXyrix) {
      _appendSelfTestLog('[事件] FileListEvent: ${files.length} 个文件');
    }
    _lastFileList = files;
    _emit(FileListEvent(files));
    final completer = _fileListCompleter;
    _fileListCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(files);
    }
  }

  // ------------------------------------------------------------------
  // 实时音频流（0x54 OPUS 推送）本地落盘
  // ------------------------------------------------------------------

  void _onOpusPacket(XyrixOpusPacket packet) {
    _accountPacket(packet);
    _rtQueue.add(packet);
    if (_rtSink != null) {
      _flushRtQueue();
    } else if (!_rtOpening) {
      // 打开捕获文件要 await 一次平台通道，首包（以及打开期间到达的包）
      // 必须先入队，否则第一包正好丢掉——真机实测首包就在 await 期间到达
      _rtOpening = true;
      _openRealtimeCapture().then((_) {
        _rtOpening = false;
        _flushRtQueue();
      });
    }
    _rtIdleTimer?.cancel();
    // 设备端停止/异常断流时兜底收尾
    _rtIdleTimer = Timer(const Duration(seconds: 8), _closeRealtimeCapture);
  }

  /// 包连续性对账。GATT 通知本身保序，所以序列号不连续就是设备侧丢包，
  /// 落盘的 opus 内容不再完整——这个结论必须传到上层，不能只打日志。
  void _accountPacket(XyrixOpusPacket packet) {
    final last = _rtLastSeq;
    if (last != null) {
      if (packet.seq == last) {
        debugPrint('[Xyrix] 实时流重复包 seq=${packet.seq}');
      } else if (packet.seq < last) {
        _rtOutOfOrder++;
      } else if (packet.seq > last + 1) {
        final missing = packet.seq - last - 1;
        _rtSeqGaps += missing;
        debugPrint(
          '[Xyrix] 实时流序列号跳变 $last → ${packet.seq}，'
          '缺 $missing 包',
        );
      }
    }
    _rtLastSeq = packet.seq;
  }

  void _flushRtQueue() {
    final sink = _rtSink;
    if (sink == null || _rtQueue.isEmpty) return;
    for (final packet in _rtQueue) {
      sink.add(packet.payload);
      _rtPayloadBytes += packet.payload.length;
      _rtPackets++;
      _rtPacketsTotal++;
    }
    _rtQueue.clear();
  }

  /// 打开实时音频落盘文件。
  ///
  /// ⚠️ 这个名字带 `.opus` 只是「设备 0x54 流的原样存档」，**不是标准 Ogg Opus**，
  /// 普通播放器打不开。2026-10-06 拿 890,054B 的真机原始推流存档（10,097 包）
  /// 试过把它解成可播放文件，结论是**载荷不是裸 Opus 包**：
  ///  - 按 `[1B 子记录长度][8B 以 0x48 结尾的子记录头][音频][2B CRC]` 取 offset=9
  ///    当 Opus TOC，98.6% 的配置位合法（随机字节只有约 56%），说明边界是对的；
  ///  - 但**声道位 5350 单声道 / 4746 立体声对半开**，同一条流里不可能；
  ///    配置位也在 cfg7(SILK WB) 与 cfg17(CELT FB) 之间来回跳，帧数码 0..3 全都有；
  ///  - 套上 Ogg 容器交给 libopus 解：9,980 段里 **6,301 段直接 TOC 解析失败**，
  ///    解出来的 8.4MB PCM 也谈不上是语音。
  /// 再往前一步的猜测（offset 8 看着 99.5% 合法）是假的——那是在数 0x48 标记本身，
  /// 0x48 当 TOC 恰好是合法的 cfg9。
  /// 所以缺的是厂商的音频载荷封装规则（每段前面很可能还有一层厂商自己的头，
  /// 或者一包里装多帧/双声道交织）。传输层能保证的只有**字节完整**
  /// （seq 连续、0 丢包）——**别照着这段去写解码器**。
  ///
  /// 2026-10-06 又补了两条硬证据，这条路上不用再试了：
  ///  - **封装边界是确定的**：753,309B 存档按 `[1B L][7×00][0x48][L-1B 载荷]`
  ///    全程走到底只重同步 2 次，切出 10,588 段。问题不在边界，在载荷本身。
  ///  - **不是 Opus，是协议层面就不合法**：最大的一段类首字节 0x3A 拆开是
  ///    config=7(SILK) + code=2(两帧不等长 CBR)，RFC 6716 里 SILK 不能用 code 2；
  ///    这一类 3,679 段全部被 ffmpeg 拒收。0x8D = config 17 + code 5 同理。
  ///    对照组：拿 ffmpeg 自己编码的 Opus 包走同一个 Ogg 打包器，0 错误、时长对得上，
  ///    所以不是打包器的锅。
  ///
  /// 也别指望从厂商交付包里找到解码器：`app-release.apk` 的 `lib/arm64-v8a/`
  /// 只有 `libflutter.so` + `libapp.so` + `libandroidx.graphics.path.so`，
  /// 没有任何 opus/ogg 相关符号（`libapp.so` 里连 `opus`/`ogg`/`decode`
  /// 都搜不到，只剩框架自带的媒体键名）。AAR 里的 `libSDK.so` 也查过了，
  /// 导出只有 `Java_com_nveasy_ble_Auth_auth/init` 和
  /// `Java_com_nveasy_ble_NoiseCancellation_init/process`，字符串全是
  /// `gtcrn_encoder_GTConvBlock_*`/`gtcrn_erb_fc_Linear_*`——那是 **GTCRN 语音增强
  /// 网络的权重**，输入是 PCM，不是解码器。**Demo 只搬字节，不解码**——
  /// 「解码」从来就不在这套 SDK 的交付范围内。
  Future<void> _openRealtimeCapture() async {
    if (_rtSink != null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      // 原始存档改名 .raw：它不是任何可播放格式，只是逐字节的传输证据。
      // 可播放的那份由 _rtAccumulator + XyrixOpusMuxer 另存成 .opus。
      _rtFile = File('${dir.path}/xyrix_rt_$ts.raw');
      _rtOggFile = File('${dir.path}/xyrix_rt_$ts.opus');
      _rtAccumulator = XyrixChunkAccumulator();
      final oggSink = _rtOggSink = _rtOggFile!.openWrite();
      _rtMuxer = XyrixOpusMuxer(
        onPage: (page) => oggSink.add(page),
        samplesPerPacket: 960,
      )..start();
      _rtSink = _rtFile!.openWrite();
      debugPrint('[Xyrix] 实时音频捕获开始: ${_rtFile!.path}');
    } catch (e) {
      debugPrint('[Xyrix] 打开实时捕获失败: $e');
    }
  }

  Future<void> _closeRealtimeCapture() async {
    // 先收尾 Ogg：不 finish() 就没有 EOS 页，播放器会认为文件被截断。
    final muxer = _rtMuxer;
    final oggSink = _rtOggSink;
    _rtMuxer = null;
    _rtOggSink = null;
    final accumulator = _rtAccumulator;
    _rtAccumulator = null;
    if (muxer != null && oggSink != null) {
      try {
        muxer.finish();
        await oggSink.flush();
        await oggSink.close();
        debugPrint(
          '[Xyrix] 实时 Opus 收尾：包 ${accumulator?.packetsEmitted ?? 0}，'
          '重同步跳过 ${accumulator?.skippedBytes ?? 0} B → ${_rtOggFile?.path}',
        );
      } catch (e) {
        debugPrint('[Xyrix] 实时 Opus 收尾失败: $e');
        try {
          await oggSink.close();
        } catch (_) {}
      }
    }
    _rtIdleTimer?.cancel();
    _rtIdleTimer = null;
    _flushRtQueue();
    final sink = _rtSink;
    final file = _rtFile;
    final bytes = _rtPayloadBytes;
    final packets = _rtPackets;
    final gaps = _rtSeqGaps;
    final outOfOrder = _rtOutOfOrder;
    final avgPacketBytes = packets > 0 ? (bytes / packets).round() : 0;
    _rtSink = null;
    _rtFile = null;
    _rtPayloadBytes = 0;
    _rtPackets = 0;
    _rtLastSeq = null;
    _rtSeqGaps = 0;
    _rtOutOfOrder = 0;
    if (sink == null || file == null) return;
    try {
      await sink.flush();
      await sink.close();
    } catch (_) {}
    debugPrint(
      '[Xyrix] 实时音频落盘完成 $packets 包 / $bytes B'
      '（丢包 $gaps，乱序 $outOfOrder）→ ${file.path}',
    );
    if (bytes > 0) {
      // 丢过包 = 内容缺失，按 sizeMismatch 上报，上层不得把它当可用录音
      final lostBytes = gaps * avgPacketBytes;
      _emit(
        FileImportedEvent(
          ImportedRecording(
            filePath: file.path,
            actualBytes: bytes,
            expectedBytes: bytes + lostBytes,
            integrity:
                gaps == 0
                    ? TransferIntegrity.verified
                    : TransferIntegrity.sizeMismatch,
          ),
        ),
      );
    }
  }

  // ------------------------------------------------------------------
  // 自驱动联调（Config.selfTestXyrix）：自动 录音→停止→刷新列表 并写报告
  // ------------------------------------------------------------------

  /// 自测进行中标记（防止重复触发）
  bool _selfTestRunning = false;

  void _maybeStartSelfTest() {
    if (!Config.selfTestXyrix) return;
    // connect() 可能被自动重连+手动操作触发两次，自测只跑一次
    if (_selfTestRunning) return;
    _selfTestRunning = true;
    _appendSelfTestLog(
      '=== 连接成功，下载自测开始 ${DateTime.now().toIso8601String()} ===',
    );
    Timer(const Duration(seconds: 3), () async {
      RecordingFile? target;
      try {
        final files = await listFiles();
        await _appendSelfTestLog('[1] 列表: ${files.length} 个文件');
        // 选最小的文件下载（141KB 级别，BLE 约 1-2 分钟）
        final sorted = [...files]
          ..sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
        target = sorted.isEmpty ? null : sorted.first;
        await _appendSelfTestLog(
          '[2] 下载目标: ${target?.name} (${target?.sizeBytes} B)',
        );
      } catch (e) {
        await _appendSelfTestLog('[1] 列表刷新失败: $e');
      }
      if (target == null) {
        await _appendSelfTestLog('=== 自测结束（无目标） ===');
        _selfTestRunning = false;
        return;
      }
      try {
        await downloadFile(target, transport: TransferTransport.ble);
        await _appendSelfTestLog('[3] 下载完成');
      } catch (e) {
        await _appendSelfTestLog('[3] 下载失败/中断: $e');
      }
      try {
        final dir = await getApplicationDocumentsDirectory();
        final f = File('${dir.path}/xyrix_dl_${target.name}');
        final exists = await f.exists();
        await _appendSelfTestLog(
          '[4] 输出文件: ${exists ? "${await f.length()} B" : "不存在"}',
        );
      } catch (_) {}
      await _appendSelfTestLog(
        '=== 自测结束 ${DateTime.now().toIso8601String()} ===',
      );
      _selfTestRunning = false;
    });
  }

  /// 探测台入口：`flutter run --dart-define=XYRIX_PROBE=1..5` 时连接成功后自动跑
  void _maybeStartProbe() {
    _resolveProbePlan().then((plan) {
      final level = plan.$1, only = plan.$2;
      if (level == 0 && only == 0) return;
      Timer(const Duration(seconds: 4), () async {
        debugPrint('[Xyrix][探测] 开始，level=$level only=$only');
        try {
          await XyrixProbe(
            this,
            deviceName: _connectedName,
          ).run(level, onlyLevel: only);
        } catch (e) {
          debugPrint('[Xyrix][探测] 整体异常: $e');
        }
      });
    });
  }

  /// 运行时探测计划：`<外部文件目录>/xyrix_probe.txt`，内容形如 `4 only` 或 `3`，
  /// `0` 表示关闭。有这个文件时以它为准——联调时改一个文件比重新出一遍包快得多。
  Future<(int, int)> _resolveProbePlan() async {
    final fallback = (Config.xyrixProbeLevel, Config.xyrixProbeOnly);
    if (!Platform.isAndroid) return fallback;
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return fallback;
      final file = File('${dir.path}/xyrix_probe.txt');
      if (!await file.exists()) return fallback;
      final lines = (await file.readAsString()).split('\n');
      // 第二行是运行时实验选项，例：`mode=2 largest`
      if (lines.length > 1) {
        for (final opt in lines[1].trim().split(RegExp(r'\s+'))) {
          if (opt.startsWith('name=')) {
            Config.downloadNameContains = opt.substring(5);
          } else if (opt.startsWith('skip=')) {
            Config.downloadIndex = int.tryParse(opt.substring(5)) ?? 0;
          } else if (opt == 'newest') {
            Config.downloadNewest = true;
          } else if (opt.startsWith('tcp=')) {
            Config.wifiServerOverride = opt.substring(4);
          } else if (opt.startsWith('ap=')) {
            Config.wifiApCredential = opt.substring(3);
          } else if (opt.startsWith('host=')) {
            Config.wifiTcpTarget = opt.substring(5);
          } else if (opt.startsWith('mtu=')) {
            Config.dlRequestMtu = int.tryParse(opt.substring(4)) ?? 0;
          }
        }
        debugPrint(
          '[Xyrix][探测] 下载选项 downloadIndex=${Config.downloadIndex} '
          'newest=${Config.downloadNewest} name=${Config.downloadNameContains}',
        );
        // 只报「有没有配、SSID 前缀」，口令一个字符都不落日志
        debugPrint(
          '[Xyrix][探测] 快传参数 '
          '替身=${Config.wifiServerOverride.isEmpty ? "无" : Config.wifiServerOverride} '
          '带外AP=${Config.wifiApCredential.isEmpty ? "无" : "${Config.wifiApCredential.split(':').first}/*"} '
          'TCP端点=${Config.wifiTcpTarget.isEmpty ? "扫描" : Config.wifiTcpTarget}',
        );
      }
      final parts = lines.first.trim().split(RegExp(r'\s+'));
      final level = parts.isEmpty ? null : int.tryParse(parts.first);
      if (level == null) return fallback;
      if (level == 0) return (0, 0);
      final only = parts.length > 1 && parts[1] == 'only';
      return only ? (level, level) : (level, 0);
    } catch (e) {
      debugPrint('[Xyrix][探测] 读取探测计划失败: $e');
      return fallback;
    }
  }

  @override
  Future<void> hold(int seconds, String why) async {
    debugPrint('[Xyrix][探测] 留观测窗口 ${seconds}s：$why');
    await Future<void>.delayed(Duration(seconds: seconds));
  }

  /// 探测台：让手机加入设备热点并确认真的连上了
  @override
  Future<String> joinHotspot(String ssid, String password, int seconds) async {
    try {
      await _hotspotConnector.connect(ssid, password);
    } on HotspotException catch (e) {
      return '建议被系统拒绝 ${e.code}: ${e.message}';
    }
    var sawAnySsid = false;
    var last = '';
    final until = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(until)) {
      final r = await _hotspotConnector.currentSsid();
      if (r.ssid.isNotEmpty) sawAnySsid = true;
      last = r.ssid;
      if (r.linked && r.ssid == ssid) return '已连上 $ssid';
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    // 全程一个 SSID 都读不到 = 手机不给定位权限，是观测失效不是设备失败
    if (!sawAnySsid) return '读不到当前 SSID（缺定位权限，观测失效）';
    return '未连上（仍在 $last）';
  }

  /// 探测台：打印 GATT 全表（服务/特征/属性/描述符）+ 可选 MTU 请求
  @override
  Future<String> runGattSurvey() async {
    final dev = _device;
    if (dev == null) return '未连接';
    final out = <String>[];
    final services = await dev.discoverServices();
    for (final s in services) {
      out.add('S=${s.uuid.str}');
      for (final c in s.characteristics) {
        final p =
            <String>[
              if (c.properties.read) 'R',
              if (c.properties.write) 'W',
              if (c.properties.writeWithoutResponse) 'w',
              if (c.properties.notify) 'N',
              if (c.properties.indicate) 'I',
            ].join();
        final dsc = c.descriptors.map((d) => d.uuid.str).join(',');
        out.add('C=${c.uuid.str}[$p]D=$dsc');
      }
    }
    if (Config.dlRequestMtu > 0) {
      try {
        final negotiated = await dev.requestMtu(Config.dlRequestMtu);
        out.add('MTU $Config.dlRequestMtu→$negotiated');
      } catch (e) {
        out.add('MTU请求失败 $e');
      }
    }
    debugPrint('[Xyrix][GATT] ${out.join('  ')}');
    return out.join(' | ');
  }

  /// 按 `Config.downloadNameContains / downloadNewest / downloadIndex`
  /// 从设备列表里挑一个下载目标（BLE 与 WiFi 两条闭环共用同一套选文件规则，
  /// 否则两边测的就不是同一个文件，对比结果没有意义）
  Future<RecordingFile?> _pickDownloadTarget() async {
    final files = _lastFileList.isEmpty ? await listFiles() : _lastFileList;
    if (files.isEmpty) return null;
    final sorted = [...files]
      ..sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
    final wanted = Config.downloadNameContains;
    if (wanted.isNotEmpty) {
      return files.firstWhere(
        (f) => f.name.contains(wanted),
        orElse: () => files.first,
      );
    }
    return Config.downloadNewest
        ? files.first
        : sorted[Config.downloadIndex.clamp(0, sorted.length - 1)];
  }

  /// 完整跑一遍 BLE 下载闭环并给出结论（探测台 level 3 用）
  @override
  Future<String> runBleDownload() async {
    final target = await _pickDownloadTarget();
    if (target == null) return '设备上无文件';
    final sw = Stopwatch()..start();
    await downloadFile(target, transport: TransferTransport.ble);
    sw.stop();
    final secs = sw.elapsedMilliseconds / 1000.0;
    return '${target.name} 期望 ${target.sizeBytes}B，'
        '实收 $_dlReceived/$_dlExpectedBytes B，integrity=$_dlIntegrity，'
        '用时 ${sw.elapsedMilliseconds}ms'
        '${secs > 0 ? "（约 ${(target.sizeBytes / 1024 / secs).round()} KB/s）" : ""}';
  }

  /// 完整跑一遍 WiFi 快传闭环（探测台 level 4 用）。
  ///
  /// 厂商的热点启用规则还没给，所以这一步在 `Config.wifiServerOverride`
  /// 指向的替身服务器上跑：把「开热点 + 手机入网」两步跳过，专门验
  /// `0x46 → TCP → .part → finalize → 完整性判定` 这条数据通路本身。
  /// 这样规则一到手就能直接接上，而不是还有一整段没验过的代码。
  @override
  Future<String> runWifiDownload() async {
    final target = await _pickDownloadTarget();
    if (target == null) return '设备上无文件';
    final sw = Stopwatch()..start();
    try {
      await downloadFile(target, transport: TransferTransport.wifi);
    } catch (e) {
      return '${target.name} WiFi 失败: $e';
    }
    sw.stop();
    final s = _lastWifiSession;
    if (s == null) return '${target.name} WiFi 无结果上报';
    return '${target.name} ${s.verdict}，用时 ${sw.elapsedMilliseconds}ms';
  }

  String? _connectedName;

  /// 会话内累计收到的音频包数（捕获文件的计数器会随关闭清零，这个不会——
  /// 录音生命周期观测要靠它判断「暂停后确实不再推流」）
  int _rtPacketsTotal = 0;

  /// 录音生命周期实测：录音类命令在本版固件**无回执**，所以效果只能看
  /// 0x54 推流是否起/停、以及设备上是否多出一个文件来判定。
  @override
  Future<String> runRecordLifecycle() async {
    final m0 = _rtPacketsTotal;
    final before = _lastFileList.length;
    await startRecord(RecordScene.meeting);
    await hold(12, '录音中观察推流');
    final m1 = _rtPacketsTotal;
    await pauseRecord();
    await hold(8, '暂停后观察推流');
    final m2 = _rtPacketsTotal;
    await resumeRecord();
    await hold(8, '恢复后观察推流');
    final m3 = _rtPacketsTotal;
    await stopRecord();
    await hold(20, '等设备写盘');
    final after = (await listFiles()).length;
    return '推流包数 开始+${m1 - m0} 暂停+${m2 - m1} 恢复+${m3 - m2}，'
        '设备文件 $before→$after';
  }

  /// 发 BLE 下载启动帧：`FF 55 AA 02 00 08 00`（命令码 0x00，数据 [08 00]）。
  ///
  /// 2026-10-06 真机定案：`0x07 [绝对路径][4B 大小 BE]` → 设备回 `0x2D`+ACK →
  /// 必须再发这条 0x00，设备才开始经 Nordic UART 通知特征推 488B 数据块。
  /// 文档把 0x08 记作「杰理启动帧」、0x00 记作「Telink 启动帧」，但本卡对 0x08 的
  /// 15 种时机/载荷组合全部零字节，只有 0x00 验通（77977B 收满 77977/77977）。
  Future<void> _sendDlStart() async {
    debugPrint('[Xyrix] 发下载启动帧 0x00 [08 00]');
    await sendCommand(XyrixCommands.transferStartTelink, const [0x08, 0x00]);
  }

  Future<void> _appendSelfTestLog(String line) async {
    debugPrint('[Xyrix][自测] $line');
    try {
      final dir = await getApplicationDocumentsDirectory();
      await File(
        '${dir.path}/xyrix_selftest_report.txt',
      ).writeAsString('$line\n', mode: FileMode.append);
    } catch (_) {}
  }

  void _dispatchFrame(XyrixFrame frame) {
    _resolveWaiters(frame);
    switch (frame.command) {
      case XyrixCommands.queryBattery:
        if (frame.data.length >= 2) {
          _emit(
            BatteryEvent(
              BatteryStatus(
                levelPercent: frame.data[0],
                isCharging: frame.data[1] == 0x01,
              ),
            ),
          );
        }
        break;
      case XyrixCommands.queryVersion:
        if (frame.data.isEmpty) break;
        final raw = String.fromCharCodes(frame.data);
        // 响应形如 "2025/01/01-12:00:00 v2.0.13"（联调实测），展示末段版本号
        final version = raw.trim().split(RegExp(r'\s+')).last;
        _emit(DeviceInfoEvent(DeviceHardwareInfo(firmwareVersion: version)));
        break;
      case XyrixCommands.queryDeviceId:
        // 联调实测此版固件对 0xFF 无响应；SN 改由广播厂商数据解析
        _emit(
          DeviceInfoEvent(
            DeviceHardwareInfo(serialNumber: String.fromCharCodes(frame.data)),
          ),
        );
        break;
      case XyrixCommands.commandAck:
        // 命令完成 ACK（文件列表结束帧已在收集模式中拦截，不会到这里）
        break;
      case XyrixCommands.transferReady:
        // 传输准备就绪（数据 = 4B 文件大小 BE），收到后才启动 0x08
        _onTransferReady(frame.data);
        break;
      case XyrixCommands.queryStorage:
        final storage = XyrixFrameCodec.parseStorage(frame.data);
        if (storage != null) {
          _emit(
            DeviceInfoEvent(
              DeviceHardwareInfo(
                storageTotalKb: storage.totalKb,
                storageFreeKb: storage.freeKb,
              ),
            ),
          );
        } else {
          debugPrint('[Xyrix] 存储响应无法解析: ${frame.data}');
        }
        break;
      case XyrixCommands.recordCardStatus:
        // 真机实测：4 字节，本版固件在空闲态回 `00 00 00 00`，字段语义未确认。
        // 不做猜测性解释——只留原始字节供后续联调比对。
        debugPrint(
          '[Xyrix] 录音卡状态(0x1A) 原始字节: '
          '${frame.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        );
        break;
      case XyrixCommands.fileInfo:
        // 真机实测 0x04 无响应（与 0xFF 同），文件详情只能从 0x05 列表行取
        break;
      case 0xE0:
        // 未文档化帧（2026-10-06 Telink 0x43+0x00 之后出现 `FF 55 AA 02 E0 00 11`）。
        // 疑与传输/状态相关，语义未知，先原样记录
        debugPrint(
          '[Xyrix] 未文档化 0xE0 帧: '
          '${frame.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        );
        break;
      case XyrixCommands.recordStart:
        _emit(RecordStateEvent(RecordState.recording));
        break;
      case XyrixCommands.recordSave:
      case XyrixCommands.opusEnd:
        _emit(RecordStateEvent(RecordState.idle));
        break;
      case XyrixCommands.recordPause:
      case XyrixCommands.opusPause:
        _emit(RecordStateEvent(RecordState.paused));
        break;
      case XyrixCommands.openHotspot:
      case XyrixCommands.openHotspotTcp:
        // 设备对「开热点」的响应：预期携带 SSID/密码（格式待厂商文档确认，
        // 宽松解析 + 原始字节日志，真机联调后精化）
        debugPrint(
          '[Xyrix] 热点响应帧 data='
          '${frame.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')} '
          'ascii="${ascii.decode(frame.data, allowInvalid: true)}"',
        );
        _wifiTransfer?.onHotspotCredentialsFrame(frame.data);
        break;
      case XyrixCommands.closeWifi:
      case XyrixCommands.wifiTransferStop:
        // 收尾命令的回执，无需处理
        break;
      default:
        // 联调期未知命令帧全量打印：热点凭证等未确认格式的响应都从这里暴露
        debugPrint(
          '[Xyrix] 未处理帧 cmd=0x${frame.command.toRadixString(16).padLeft(2, '0')} '
          'len=${frame.data.length} '
          'data=${frame.data.take(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        );
        break;
    }
  }

  // ------------------------------------------------------------------
  // BleDeviceAdapter 接口
  // ------------------------------------------------------------------

  @override
  Future<void> queryDeviceInfo() async {
    // 0xFF（蓝牙设备号）此版固件无响应，SN 在连接时取自广播厂商数据
    await sendCommand(XyrixCommands.queryBattery);
    await sendCommand(XyrixCommands.queryVersion);
    await sendCommand(XyrixCommands.queryStorage);
  }

  @override
  Future<void> startRecord(RecordScene mode) async {
    // 0x24（边录边传）在本版固件（v2.0.13）上无推流也不保存，弃用；
    // 0x1B 录音实测既存 WAV 又推送实时音频流，两种场景统一使用
    //（2026-09-30 自测：0x24 15s 无包，0x1B 15s 648 包 / 55KB）
    await sendCommand(XyrixCommands.recordStart);
    // 厂商协议无命令确认帧：GATT 写入成功即视为已生效（录音中设备会直接
    // 开始推送数据流），否则 UI 永远等不到状态回调
    _emit(RecordStateEvent(RecordState.recording));
  }

  @override
  Future<void> pauseRecord() async {
    await sendCommand(XyrixCommands.recordPause);
    await sendCommand(XyrixCommands.opusPause);
    await _closeRealtimeCapture();
    _emit(RecordStateEvent(RecordState.paused));
  }

  @override
  Future<void> resumeRecord() async {
    await sendCommand(XyrixCommands.recordResume);
    _emit(RecordStateEvent(RecordState.recording));
  }

  @override
  Future<void> stopRecord() async {
    // 0x1D 保存 WAV 段；实测它不会停止实时推流，补 0x53 结束 OPUS 流
    //（2026-09-30 抓包：只发 0x1D 时设备持续推流到断连）
    await sendCommand(XyrixCommands.recordSave);
    await sendCommand(XyrixCommands.opusEnd);
    await _closeRealtimeCapture();
    _emit(RecordStateEvent(RecordState.idle));
    // 设备保存 WAV 耗时随录音时长增长（十几分钟的录音保存可能远超 2 秒），
    // 固定延迟单次刷新会拿不到新文件：按 2s/6s/12s 轮询，列表出现新文件
    // 或三次跑完为止
    _schedulePostRecordListRefresh();
  }

  void _schedulePostRecordListRefresh() {
    _listRefreshTimer?.cancel();
    _listRefreshAttempt = 0;
    _listRefreshBaseCount = _lastFileList.length;
    void attempt() {
      _listRefreshAttempt++;
      final delay =
          _listRefreshAttempt == 1
              ? const Duration(seconds: 2)
              : const Duration(seconds: 4);
      _listRefreshTimer = Timer(delay, () async {
        if (_writeChar == null || _downloading) return;
        try {
          final files = await listFiles();
          debugPrint(
            '[Xyrix] 录音停止后第 $_listRefreshAttempt 次刷新列表：'
            '${files.length} 个文件（此前 $_listRefreshBaseCount 个）',
          );
          if (files.length > _listRefreshBaseCount) return; // 新录音已出现
        } catch (_) {}
        if (_listRefreshAttempt < 3) attempt();
      });
    }

    attempt();
  }

  @override
  Future<void> addMark() async {
    // Xyrix 命令表无独立打标命令；以确认帧 0x30 预留
    throw HardwareException(
      HardwareErrorCode.unsupportedCapability,
      'Xyrix 命令表未提供录音标记命令',
    );
  }

  @override
  Future<List<RecordingFile>> listFiles() async {
    if (_downloading) {
      // 下载中设备通知字节被整包写进目标文件，列表响应会被当成文件数据
      // 污染下载内容（stopRecord 的刷新定时器是异步触发，可能撞上紧随其
      // 后的下载），直接拒绝
      throw HardwareException(
        HardwareErrorCode.resourceBusy,
        '文件传输进行中，暂不能刷新列表',
      );
    }
    final completer = Completer<List<RecordingFile>>();
    _fileListCompleter?.complete(_lastFileList);
    _fileListCompleter = completer;
    await sendCommand(
      XyrixCommands.fileList,
      XyrixFrameCodec.pathData('0:/ .wav'),
    );
    // 24 个文件实测约 2.5s 传完；超时则终止收集并回退最近一次结果
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _resetFileListState();
        _emit(
          const HardwareErrorEvent(
            HardwareErrorCode.transferInterrupted,
            '设备文件列表刷新超时，请检查设备连接后重试',
          ),
        );
        return _lastFileList;
      },
    );
  }

  /// 音频外传快传：设备热点 + TCP 直传（流程见 xyrix_wifi_transfer.dart）
  Future<void> _runWifiTransfer(
    RecordingFile file, {
    bool resume = true,
  }) async {
    if (_wifiTransfer != null) {
      throw HardwareException(HardwareErrorCode.resourceBusy, '已有快传进行中');
    }
    if (_downloading) {
      throw HardwareException(HardwareErrorCode.resourceBusy, '已有蓝牙下载进行中');
    }
    if (_writeChar == null) {
      throw HardwareException(HardwareErrorCode.connectionLost, '设备未连接');
    }
    final session = XyrixWifiTransferSession(
      file: file,
      sendCommand: sendCommand,
      emit: _emit,
      hotspotConnector: _hotspotConnector,
      resume: resume,
    );
    _wifiTransfer = session;
    _lastWifiSession = session;
    try {
      await session.run();
    } finally {
      _wifiTransfer = null;
    }
  }

  @override
  Future<void> downloadFile(
    RecordingFile file, {
    TransferTransport transport = TransferTransport.ble,
    bool autoDelete = false,
    bool resume = true,
  }) async {
    if (transport == TransferTransport.wifi) {
      return _runWifiTransfer(file, resume: resume);
    }
    if (_downloading) {
      throw HardwareException(HardwareErrorCode.resourceBusy, '已有下载进行中');
    }
    if (_writeChar == null) {
      throw HardwareException(HardwareErrorCode.connectionLost, '设备未连接');
    }
    final completer = Completer<void>();
    _dlCompleter = completer;
    _downloading = true;
    _dlSource = file;
    _dlReceived = 0;
    _dlListBytes = file.sizeBytes;
    _dlExpectedBytes = file.sizeBytes;
    _dlFirstPacketLogged = false;
    _dlStartTime = DateTime.now();
    _dlLastProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final target = TransferTarget.inDirectory(
        dir,
        file.name,
        prefix: 'xyrix_dl_',
      );
      // Xyrix BLE 协议（0x07 只带路径+大小）没有偏移语义，残留断点属于
      // 上一次的无效字节，必须清掉从头重传
      await target.discard();
      _dlTarget = target;
      _dlSink = target.partFile.openWrite();
      _emitDownloadProgress(TransferState.transferring, force: true);
      // 0x07 数据 = 路径 + 4 字节大端文件大小。实测设备会回
      // `FF 55 AA 04 2D [4B 大小 BE]` + ACK（传输准备就绪），
      // 必须等它到了再发 0x08，否则 0x08 被丢弃、数据永不到来
      final pathBytes = utf8.encode('0:/${file.name}');
      final sz = file.sizeBytes;
      _dlAwaitingReady = true;
      await sendCommand(XyrixCommands.transferPrepareJl, [
        ...pathBytes,
        (sz >> 24) & 0xFF,
        (sz >> 16) & 0xFF,
        (sz >> 8) & 0xFF,
        sz & 0xFF,
      ]);
      _dlPrepareTimer = Timer(const Duration(seconds: 10), () {
        if (_downloading && _dlAwaitingReady) {
          _appendSelfTestLog('[下载] 10s 未收到 0x2D 就绪应答，终止');
          _finishDownload(
            TransferState.failed,
            stopIntent: TransferStopIntent.interrupted,
          );
        }
      });
    } catch (e) {
      await _finishDownload(
        TransferState.failed,
        stopIntent: TransferStopIntent.interrupted,
      );
      rethrow;
    }
    return completer.future;
  }

  /// 设备 0x2D 应答：数据为 4 字节大端文件大小。
  /// **这条结论已存疑，不要当定论**：2026-09-30 联调记的是「收到 0x2D 后设备自动
  /// 下发数据、发 0x08 反会被丢弃」；2026-10-05 在同一张卡（SN 2606260101400084、
  /// v2.0.13）复测，0x07→0x2D 之后 0 字节下发（换文件、空闲、重启后都如此），补发
  /// 0x08 同样 0 字节，改走 Telink 0x43+0x00 才拿到回执（状态 03 + 未文档化的 0xE0
  /// 帧）。且 0x2D 回的大小与我们在 0x07 里声明的一模一样，是回显而非「设备已备好
  /// 文件」的确认——真正的门禁在下一步的 0x00 启动帧上（见 [_sendDlStart]）。
  Future<void> _onTransferReady(List<int> data) async {
    if (!_dlAwaitingReady) return;
    _dlAwaitingReady = false;
    _dlPrepareTimer?.cancel();
    _dlPrepareTimer = null;
    final confirmedSize =
        data.length >= 4
            ? (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3]
            : 0;
    if (confirmedSize > 0) {
      if (_dlListBytes > 0 && confirmedSize != _dlListBytes) {
        // 列表与设备不一致 = 设备侧文件在此期间被改写，以设备为准
        debugPrint(
          '[Xyrix] 大小对账不一致：列表 $_dlListBytes B，'
          '设备确认 $confirmedSize B，改用设备值',
        );
        if (Config.selfTestXyrix) {
          _appendSelfTestLog(
            '[下载] 大小对账不一致 列表=$_dlListBytes '
            '设备=$confirmedSize，改用设备值',
          );
        }
      }
      _dlExpectedBytes = confirmedSize;
    } else {
      _dlExpectedBytes = _dlListBytes;
    }
    debugPrint('[Xyrix] 传输就绪，校验基准 $_dlExpectedBytes B，等待数据下发');
    if (Config.selfTestXyrix) {
      _appendSelfTestLog(
        '[下载] 0x2D 就绪应答，设备确认大小 $confirmedSize B，'
        '校验基准 $_dlExpectedBytes B',
      );
    }
    _armStallWatchdog();
    await _sendDlStart();
  }

  /// 下载中收到设备数据：原样写入断点文件并按字节推进度。
  ///
  /// 过收（超出校验基准）说明有控制帧/ACK 被当成文件字节写入，内容已不可信，
  /// 立即终止而不是等它「凑够」。
  void _onDownloadBytes(List<int> value) {
    _dlSink?.add(value);
    _dlReceived += value.length;
    _dlStallTimer?.cancel();
    _armStallWatchdog();
    if (!_dlFirstPacketLogged) {
      _dlFirstPacketLogged = true;
      debugPrint(
        '[Xyrix] 首个数据包 ${value.length}B: '
        '${value.take(48).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
      if (Config.selfTestXyrix) {
        _appendSelfTestLog(
          '[下载] 首包 ${value.length}B: '
          '${value.take(48).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
        );
      }
    }
    if (_dlExpectedBytes > 0 && _dlReceived > _dlExpectedBytes) {
      debugPrint(
        '[Xyrix] 过收：已收 $_dlReceived B > 基准 $_dlExpectedBytes B，'
        '判定传输污染',
      );
      _finishDownload(
        TransferState.failed,
        stopIntent: TransferStopIntent.interrupted,
        reason:
            '收到字节超出设备确认大小（$_dlReceived > $_dlExpectedBytes），'
            '数据流被控制帧污染',
      );
      return;
    }
    if (_dlExpectedBytes > 0 && _dlReceived == _dlExpectedBytes) {
      _finishDownload(TransferState.completed);
    } else {
      // 每 32KB 向自测报告打一个进度点
      if (Config.selfTestXyrix &&
          _dlReceived ~/ 32768 != (_dlReceived - value.length) ~/ 32768) {
        _appendSelfTestLog('[下载] 进度 $_dlReceived/$_dlExpectedBytes B');
      }
      _emitDownloadProgress(TransferState.transferring);
    }
  }

  void _emitDownloadProgress(TransferState state, {bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        now.difference(_dlLastProgressEmit) <
            const Duration(milliseconds: 250)) {
      return;
    }
    _dlLastProgressEmit = now;
    final total = _dlExpectedBytes;
    final received = _dlReceived;
    final elapsedSec = now.difference(_dlStartTime).inMilliseconds / 1000.0;
    final speedKbps =
        elapsedSec > 0.2 ? (received / 1024 / elapsedSec).round() : 0;
    _emit(
      TransferProgressEvent(
        TransferProgress(
          state: state,
          receivedBytes: received,
          totalBytes: total,
          totalPacket: total > 0 ? (total / 512).ceil() : 1,
          currentPacket: total > 0 ? (received / 512).ceil() : 0,
          speedKbps: speedKbps,
          integrity: state == TransferState.transferring ? null : _dlIntegrity,
        ),
        fileSn: _dlSource?.sn,
      ),
    );
  }

  /// 上一次传输的完整性结论（进行中为 null）
  TransferIntegrity? _dlIntegrity;

  /// 收流结束：核对字节数，只有校验通过才把断点提升为正式录音。
  ///
  /// [stopIntent] 决定断点去留——用户取消 = 丢弃；意外中断 = 保留供排查
  /// （BLE 通道下次仍会从 0 重传，保留只为不丢已收字节）。
  Future<void> _finishDownload(
    TransferState endState, {
    TransferStopIntent stopIntent = TransferStopIntent.none,
    String? reason,
  }) async {
    _dlStallTimer?.cancel();
    _dlStallTimer = null;
    _dlPrepareTimer?.cancel();
    _dlPrepareTimer = null;
    _dlAwaitingReady = false;
    _downloading = false;
    final sink = _dlSink;
    final target = _dlTarget;
    final source = _dlSource;
    final received = _dlReceived;
    final expected = _dlExpectedBytes;
    _dlSink = null;
    _dlTarget = null;
    _dlSource = null;

    TransferOutcome? outcome;
    if (sink != null && target != null) {
      outcome = await target.finalize(
        sink,
        endState == TransferState.completed ? expected : 0,
      );
      _dlIntegrity = outcome.integrity;
    } else {
      _dlIntegrity = null;
    }
    debugPrint(
      '[Xyrix] 下载结束 state=$endState intent=$stopIntent '
      'received=$received/expected=$expected ${outcome ?? ''}',
    );
    if (Config.selfTestXyrix) {
      _appendSelfTestLog(
        '[下载] 结束 state=$endState intent=$stopIntent '
        'received=$received/expected=$expected integrity=${outcome?.integrity}',
      );
    }
    _emitDownloadProgress(endState, force: true);

    if (outcome != null && outcome.trusted && source != null) {
      _emit(
        FileImportedEvent(
          ImportedRecording(
            filePath: outcome.filePath,
            recordStartTime: source.startTime,
            fileSn: source.sn,
            deviceFileName: source.name,
            expectedBytes: outcome.expectedBytes,
            actualBytes: outcome.actualBytes,
            integrity: outcome.integrity,
          ),
        ),
      );
      // 下载完成后自动刷新设备文件列表（同步"已下载"标识所依赖的列表）
      Timer(const Duration(seconds: 2), () {
        listFiles()
            .then((files) {
              debugPrint('[Xyrix] 下载完成后自动刷新列表：${files.length} 个文件');
            })
            .catchError((_) {});
      });
    } else if (stopIntent == TransferStopIntent.userCancelled) {
      // 用户明确不要这份文件：断点一并作废
      await target?.discard();
    } else if (endState == TransferState.failed && source != null) {
      // 校验不通过：绝不作为录音上报，断点直接丢弃，避免半截文件被
      // 目录扫描当成一条录音导入
      await target?.discard();
      _emit(
        HardwareErrorEvent(
          outcome?.integrity == TransferIntegrity.sizeMismatch
              ? HardwareErrorCode.integrityMismatch
              : HardwareErrorCode.transferInterrupted,
          reason ?? '文件未通过完整性校验（已收 $received/$expected 字节），已丢弃',
        ),
      );
    }
    final completer = _dlCompleter;
    _dlCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  /// 数据断流看门狗：连续 15 秒无通知视为传输中断。
  /// （不按总时长超时——大文件在 BLE 上可能要传几十分钟。）
  void _armStallWatchdog() {
    _dlStallTimer?.cancel();
    _dlStallTimer = Timer(const Duration(seconds: 15), () {
      if (!_downloading) return;
      debugPrint('[Xyrix] 下载断流 15s，终止（已收 $_dlReceived/$_dlExpectedBytes）');
      _finishDownload(
        TransferState.failed,
        stopIntent: TransferStopIntent.interrupted,
        reason: '蓝牙数据断流 15 秒（已收 $_dlReceived/$_dlExpectedBytes 字节）',
      );
      if (_writeChar != null) {
        sendCommand(XyrixCommands.bleTransferStop).catchError((_) {});
      }
    });
  }

  @override
  Future<void> cancelDownload() async {
    // 取消分通道：WiFi 会话自己收尾（含关热点），BLE 走断点作废 + 0x48
    final wifi = _wifiTransfer;
    if (wifi != null) {
      await wifi.cancel();
      return;
    }
    if (_downloading) {
      await _finishDownload(
        TransferState.cancelled,
        stopIntent: TransferStopIntent.userCancelled,
      );
    }
    if (_writeChar != null) {
      await sendCommand(XyrixCommands.bleTransferStop);
    }
  }

  @override
  Future<void> deleteFile(RecordingFile file) => sendCommand(
    XyrixCommands.deleteFile,
    XyrixFrameCodec.pathData('0:/${file.name}'),
  );

  @override
  Future<void> upgradeFirmware({
    required String filePath,
    required String newVersion,
  }) async {
    throw HardwareException(
      HardwareErrorCode.unsupportedCapability,
      'Xyrix SDK 无独立 OTA API（固件升级走文件传输通道，待厂商流程确认）',
    );
  }

  @override
  Future<void> dispose() async {
    _dlStallTimer?.cancel();
    _rtIdleTimer?.cancel();
    _listRefreshTimer?.cancel();
    // 探测台正在等响应时释放掉，否则 awaitResponse 会挂到超时
    for (final waiter in _waiters.toList()) {
      if (!waiter.completer.isCompleted) waiter.completer.complete(null);
    }
    _waiters.clear();
    await _scanSub?.cancel();
    await _connSub?.cancel();
    await _notifySub?.cancel();
    await _events.close();
  }
}

/// 探测台的挂起等待项
class _FrameWaiter {
  final Set<int> commands;
  final Completer<XyrixFrame?> completer = Completer<XyrixFrame?>();

  _FrameWaiter(this.commands);
}

/// Xyrix 适配器（方案 A）：基于 flutter_blue_plus 在 Dart 层直实现 Xyrix BLE 协议。
///
/// 协议要点（XyrixSDK-2 文档 + 2026-09 真机联调实测）：
/// - 服务/特征：Nordic UART（写 6e400002…，通知 6e400003…）
/// - 帧格式：`FF 55 AA [len=N][cmd][data]`（长度字节 = 数据长度，帧总长 5+N）
/// - 设备身份：广播 manufacturerData（companyId 0xABCD）载荷即 ASCII SN
/// - 文件列表：`FF 55 AA 00 05` 起始帧 + 明文行（`路径 -字节 B -秒 s`）+ `FF 55 AA 00 2F` 结束帧
///
/// TODO(厂商确认)：
/// 1. 实时音频（OPUS 录音 0x50 系列）回传帧格式
/// 2. 文件传输响应/数据包的分帧细节（0x07/0x08 之后的数据流）
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dting/hardware/ble_device_adapter.dart';
import 'package:dting/hardware/hardware_event.dart';
import 'package:dting/hardware/models.dart';
import 'package:dting/hardware/xyrix/xyrix_commands.dart';
import 'package:dting/hardware/xyrix/xyrix_frame_codec.dart';
import 'package:dting/hardware/xyrix/xyrix_stream_parsers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';

class XyrixAdapter extends BleDeviceAdapter {
  final StreamController<HardwareEvent> _events =
      StreamController<HardwareEvent>.broadcast();

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
  late final XyrixNotificationRouter _router = XyrixNotificationRouter(
    onFrame: _dispatchFrame,
    onFileList: _onFileListParsed,
    onOpusPacket: _onOpusPacket,
  );
  Completer<List<RecordingFile>>? _fileListCompleter;
  List<RecordingFile> _lastFileList = const [];

  /// 实时音频流（0x54 OPUS 推送）本地落盘状态
  IOSink? _rtSink;
  File? _rtFile;
  int _rtPayloadBytes = 0;
  int _rtPackets = 0;
  Timer? _rtIdleTimer;

  /// BLE 文件下载状态机：0x07 准备 + 0x08 启动后设备持续推送文件数据，
  /// 数据包分帧格式厂商文档未给出（联调中按原始字节落盘 + 计数推进度），
  /// 完成判定 = 累计字节达到文件列表上报的 sizeBytes。
  bool _downloading = false;
  IOSink? _dlSink;
  File? _dlOutFile;
  RecordingFile? _dlSource;
  int _dlReceived = 0;
  int _dlTotalBytes = 0;
  bool _dlFirstPacketLogged = false;
  DateTime _dlStartTime = DateTime.now();
  DateTime _dlLastProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _dlStallTimer;
  Completer<void>? _dlCompleter;

  /// Nordic UART Service
  static final Guid _serviceUuid =
      Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid _writeUuid = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid _notifyUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

  @override
  String get vendorId => HardwareVendor.xyrix;

  @override
  String get vendorDisplayName => 'Xyrix';

  @override
  CapabilityManifest get capabilities => const CapabilityManifest({
        HardwareCapability.deleteFile,
        HardwareCapability.addMark,
        // firmwareUpgrade：无独立 OTA API，走文件传输通道，暂不开放
        // wifiTransfer：热点+TCP 快传未接入，暂不声明 → 控制层自动选 BLE 通道
      });

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
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on)
        .first
        .timeout(const Duration(seconds: 3), onTimeout: () {
      throw HardwareException(HardwareErrorCode.unknown, '蓝牙未开启');
    });
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
    final name = r.device.platformName.isNotEmpty
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
    await _connSub?.cancel();
    _connSub = dev.connectionState.listen((state) {
      // 只负责掉线检测；connected 由 connect() 流程在服务发现完成后发布，
      // 避免 GATT 链路刚建立（服务/通知均未就绪）就把 UI 置为「已连接」。
      switch (state) {
        case BluetoothConnectionState.disconnected:
          _writeChar = null;
                _emit(
              ConnectionStateEvent(device.deviceId, ConnectionPhase.disconnected));
          break;
        default:
          break;
      }
    });
    try {
      await dev.connect(autoConnect: false, timeout: const Duration(seconds: 15));
      debugPrint('[Xyrix] GATT 链路已建立，开始服务发现');
      final services = await dev.discoverServices();
      debugPrint('[Xyrix] 发现 ${services.length} 个服务: '
          '${services.map((s) => s.uuid.str).join(', ')}');
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
      await sendCommand(XyrixCommands.syncTime, XyrixFrameCodec.timeData(DateTime.now()));
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
    if (_downloading) {
      await _finishDownload(TransferState.failed);
    }
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
    debugPrint('[Xyrix] 发送命令 0x${command.toRadixString(16).padLeft(2, '0')} '
        'data=${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    await char.write(XyrixFrameCodec.encode(command, data));
  }

  void _onNotifyData(List<int> value) {
    // 1) 原始字节无条件落盘（推流音频 + 控制响应都保住）
    _streamSink?.add(value);
    // 2) 原始字节无条件打印：协议联调期间对照厂商文档用
    debugPrint('[Xyrix] 收到通知 ${value.length}B: '
        '${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    // 3) 下载进行中：字节全部计入目标文件（分帧格式未知，先原样落盘），
    //    控制帧解析暂停——随机数据可能碰巧命中命令码，干扰 UI 状态
    if (_downloading) {
      _onDownloadBytes(value);
      return;
    }
    // 4) 命令帧 / 文件列表 / 实时音频流统一由路由器分发
    _router.feed(value);
  }

  /// 文件列表解析完成：发布事件并唤醒 listFiles() 等待方
  void _onFileListParsed(List<RecordingFile> files) {
    debugPrint('[Xyrix] 文件列表解析完成：${files.length} 个文件');
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
    final sink = _rtSink;
    if (sink == null) {
      // 路由器已在 0x54 标记帧时处于流模式；正常不会到这，防御一下
      _openRealtimeCapture();
    }
    _rtSink?.add(packet.payload);
    _rtPayloadBytes += packet.payload.length;
    _rtPackets++;
    _rtIdleTimer?.cancel();
    // 设备端停止/异常断流时兜底收尾
    _rtIdleTimer = Timer(const Duration(seconds: 8), () {
      _closeRealtimeCapture();
    });
  }

  Future<void> _openRealtimeCapture() async {
    if (_rtSink != null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      _rtFile = File('${dir.path}/xyrix_rt_$ts.opus');
      _rtSink = _rtFile!.openWrite();
      _rtPayloadBytes = 0;
      _rtPackets = 0;
      debugPrint('[Xyrix] 实时音频捕获开始: ${_rtFile!.path}');
    } catch (e) {
      debugPrint('[Xyrix] 打开实时捕获失败: $e');
    }
  }

  Future<void> _closeRealtimeCapture() async {
    _rtIdleTimer?.cancel();
    _rtIdleTimer = null;
    _router.resetRealtime();
    final sink = _rtSink;
    final file = _rtFile;
    final bytes = _rtPayloadBytes;
    final packets = _rtPackets;
    _rtSink = null;
    _rtFile = null;
    _rtPayloadBytes = 0;
    _rtPackets = 0;
    if (sink == null || file == null) return;
    try {
      await sink.flush();
      await sink.close();
    } catch (_) {}
    debugPrint('[Xyrix] 实时音频落盘完成 $packets 包 / $bytes B → ${file.path}');
    if (bytes > 0) {
      _emit(FileImportedEvent(ImportedRecording(filePath: file.path)));
    }
  }

  void _dispatchFrame(XyrixFrame frame) {
    switch (frame.command) {
      case XyrixCommands.queryBattery:
        if (frame.data.length >= 2) {
          _emit(BatteryEvent(BatteryStatus(
            levelPercent: frame.data[0],
            isCharging: frame.data[1] == 0x01,
          )));
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
        _emit(DeviceInfoEvent(DeviceHardwareInfo(
          serialNumber: String.fromCharCodes(frame.data),
        )));
        break;
      case XyrixCommands.commandAck:
        // 命令完成 ACK（文件列表结束帧已在收集模式中拦截，不会到这里）
        break;
      case XyrixCommands.queryStorage:
        // TODO(厂商确认)：存储信息字节布局
        debugPrint('[Xyrix] 存储信息原始数据: ${frame.data}');
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
      default:
        // 其余响应/数据包（传输数据等）在具体功能落地时按厂商文档解析
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
    // 联调探测：会议=0x1B 仅设备端存储录音；通话=0x24 边录音边蓝牙推流，
    // 用于对比两种模式下设备是否推送实时音频流、推流字节格式如何
    await sendCommand(mode == RecordScene.call
        ? XyrixCommands.recordWithTransfer
        : XyrixCommands.recordStart);
    // 厂商协议无命令确认帧：GATT 写入成功即视为已生效（录音中设备会直接
    // 开始推送数据流），否则 UI 永远等不到状态回调
    _emit(RecordStateEvent(RecordState.recording));
  }

  @override
  Future<void> pauseRecord() async {
    await sendCommand(XyrixCommands.recordPause);
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
    await sendCommand(XyrixCommands.recordSave);
    await _closeRealtimeCapture();
    _emit(RecordStateEvent(RecordState.idle));
    // 设备保存 WAV 需要一点时间，稍后自动刷新设备文件列表，
    // 新录音不经手动下拉就能出现在列表里
    Timer(const Duration(seconds: 2), () {
      listFiles().then((files) {
        debugPrint('[Xyrix] 录音停止后自动刷新列表：${files.length} 个文件');
      }).catchError((_) {});
    });
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
    final completer = Completer<List<RecordingFile>>();
    _fileListCompleter?.complete(_lastFileList);
    _fileListCompleter = completer;
    await sendCommand(
        XyrixCommands.fileList, XyrixFrameCodec.pathData('0:/ .wav'));
    // 24 个文件实测约 2.5s 传完；超时则终止收集并回退最近一次结果
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _resetFileListState();
        return _lastFileList;
      },
    );
  }

  @override
  Future<void> downloadFile(
    RecordingFile file, {
    TransferTransport transport = TransferTransport.ble,
    bool autoDelete = false,
  }) async {
    if (transport == TransferTransport.wifi) {
      throw HardwareException(
        HardwareErrorCode.unsupportedCapability,
        'Xyrix WiFi 快传（热点+TCP）未接入，请走 BLE 通道',
      );
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
    _dlTotalBytes = file.sizeBytes;
    _dlFirstPacketLogged = false;
    _dlStartTime = DateTime.now();
    _dlLastProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final dir = await getApplicationDocumentsDirectory();
      _dlOutFile = File('${dir.path}/xyrix_dl_${file.name}');
      _dlSink = _dlOutFile!.openWrite();
      _emitDownloadProgress(TransferState.transferring, force: true);
      // 0x07 数据 = 路径 + 4 字节大端文件大小（对齐 0x46「路径 hex + 4 字节
      // 大端断点」的编码习惯；文档只写「绝对路径 + 文件大小」未给布局）
      final pathBytes = utf8.encode('0:/${file.name}');
      final size = file.sizeBytes;
      final data = BytesBuilder()..add(pathBytes);
      for (final shift in const [24, 16, 8, 0]) {
        data.addByte((size >> shift) & 0xFF);
      }
      await sendCommand(XyrixCommands.transferPrepareJl, data.toBytes());
      await sendCommand(XyrixCommands.transferStartJl);
      _armStallWatchdog();
    } catch (e) {
      await _finishDownload(TransferState.failed);
      rethrow;
    }
    return completer.future;
  }

  /// 下载中收到设备数据：原样写入目标文件并按字节推进度。
  /// 完成判定 = 累计字节达到列表上报的 sizeBytes（文件大小是已知量）。
  void _onDownloadBytes(List<int> value) {
    _dlSink?.add(value);
    _dlReceived += value.length;
    _dlStallTimer?.cancel();
    _armStallWatchdog();
    if (!_dlFirstPacketLogged) {
      _dlFirstPacketLogged = true;
      debugPrint('[Xyrix] 首个数据包 ${value.length}B: '
          '${value.take(48).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    }
    if (_dlTotalBytes > 0 && _dlReceived >= _dlTotalBytes) {
      _finishDownload(TransferState.completed);
    } else {
      _emitDownloadProgress(TransferState.transferring);
    }
  }

  void _emitDownloadProgress(TransferState state, {bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_dlLastProgressEmit) < const Duration(milliseconds: 250)) {
      return;
    }
    _dlLastProgressEmit = now;
    final total = _dlTotalBytes;
    final received = _dlReceived;
    final elapsedSec =
        now.difference(_dlStartTime).inMilliseconds / 1000.0;
    final speedKbps = elapsedSec > 0.2 ? (received / 1024 / elapsedSec).round() : 0;
    _emit(TransferProgressEvent(
      TransferProgress(
        state: state,
        receivedBytes: received,
        totalBytes: total,
        totalPacket: total > 0 ? (total / 512).ceil() : 1,
        currentPacket: total > 0 ? (received / 512).ceil() : 0,
        speedKbps: speedKbps,
      ),
      fileSn: _dlSource?.sn,
    ));
  }

  Future<void> _finishDownload(TransferState endState) async {
    _dlStallTimer?.cancel();
    _dlStallTimer = null;
    _downloading = false;
    try {
      await _dlSink?.flush();
      await _dlSink?.close();
    } catch (_) {}
    final outFile = _dlOutFile;
    final source = _dlSource;
    final received = _dlReceived;
    _dlSink = null;
    _dlOutFile = null;
    _dlSource = null;
    debugPrint('[Xyrix] 下载结束 state=$endState received=$received/'
        'expected=$_dlTotalBytes file=${outFile?.path}');
    _emitDownloadProgress(endState, force: true);
    if (endState == TransferState.completed &&
        outFile != null &&
        source != null) {
      _emit(FileImportedEvent(ImportedRecording(
        filePath: outFile.path,
        recordStartTime: source.startTime,
        fileSn: source.sn,
      )));
    }
    if (endState == TransferState.failed && outFile != null && received == 0) {
      // 一个字节都没收到就失败：清掉空文件避免留垃圾
      try {
        await outFile.delete();
      } catch (_) {}
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
      debugPrint('[Xyrix] 下载断流 15s，终止（已收 $_dlReceived/$_dlTotalBytes）');
      _finishDownload(TransferState.failed);
      if (_writeChar != null) {
        sendCommand(XyrixCommands.bleTransferStop).catchError((_) {});
      }
    });
  }

  @override
  Future<void> cancelDownload() async {
    if (_downloading) {
      await _finishDownload(TransferState.cancelled);
    }
    await sendCommand(XyrixCommands.bleTransferStop);
  }

  @override
  Future<void> deleteFile(RecordingFile file) => sendCommand(
      XyrixCommands.deleteFile, XyrixFrameCodec.pathData('0:/${file.name}'));

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
    await _scanSub?.cancel();
    await _connSub?.cancel();
    await _notifySub?.cancel();
    await _events.close();
  }
}

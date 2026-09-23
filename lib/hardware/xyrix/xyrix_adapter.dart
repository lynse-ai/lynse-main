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
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';

class XyrixAdapter extends BleDeviceAdapter {
  final StreamController<HardwareEvent> _events =
      StreamController<HardwareEvent>.broadcast();

  /// 流式接收缓冲
  Uint8List _rxBuffer = Uint8List(0);

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;

  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  StreamSubscription? _notifySub;

  /// 实时推流捕获：连接期间设备推送的所有原始字节（录音音频流 +
  /// 控制响应帧）完整落盘，供协议分析与后续音频解码
  IOSink? _streamSink;
  File? _streamFile;

  /// 文件列表收集状态：0x05 起始帧之后到 0x2F 结束帧之间是明文行
  bool _collectingFileList = false;
  final BytesBuilder _fileListRaw = BytesBuilder(copy: true);
  Completer<List<RecordingFile>>? _fileListCompleter;
  List<RecordingFile> _lastFileList = const [];

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
        HardwareCapability.wifiTransfer,
        HardwareCapability.addMark,
        // firmwareUpgrade：无独立 OTA API，走文件传输通道，暂不开放
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
          _rxBuffer = Uint8List(0);
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
    _rxBuffer = Uint8List(0);
    _resetFileListState();
    await _closeStreamCapture();
    _emit(ConnectionStateEvent(dev.remoteId.str, ConnectionPhase.disconnected));
  }

  /// 丢弃进行中的文件列表收集（断连/超时时调用）
  void _resetFileListState() {
    _collectingFileList = false;
    _fileListRaw.clear();
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
    await _notifySub?.cancel();
    _notifySub = null;
    await _device?.disconnect();
    _device = null;
    _writeChar = null;
    _rxBuffer = Uint8List(0);
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
    await char.write(XyrixFrameCodec.encode(command, data));
  }

  void _onNotifyData(List<int> value) {
    // 1) 原始字节无条件落盘（推流音频 + 控制响应都保住）
    _streamSink?.add(value);
    // 2) 原始字节无条件打印：协议联调期间对照厂商文档用
    debugPrint('[Xyrix] 收到通知 ${value.length}B: '
        '${value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    final merged = Uint8List.fromList([..._rxBuffer, ...value]);
    // 3) 文件列表收集模式：起始帧后的明文行不经过帧解析
    if (_collectingFileList) {
      _collectFileListChunk(merged);
      return;
    }
    // 4) 命令帧解析（控制面：电量/版本/录音状态等）
    final (frames, rest) = XyrixFrameCodec.decode(merged);
    // 推流音频是非命令帧数据，残余缓冲只可能是断帧尾部；超限直接清空
    //（原始数据已在上面的捕获文件中，不丢失）
    _rxBuffer = rest.length > 4096 ? Uint8List(0) : rest;
    for (final frame in frames) {
      debugPrint('[Xyrix] 解析帧 cmd=0x${frame.command.toRadixString(16)} '
          'data=${frame.data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      _dispatchFrame(frame);
    }
  }

  /// 收集文件列表明文，直到 `FF 55 AA 00 2F` 结束帧出现。
  /// 明文行格式（联调实测）：`0:/2026-09-21-09-57-34.wav -145976 B -3680 s\n`
  void _collectFileListChunk(Uint8List chunk) {
    var endIdx = -1;
    for (var i = 0; i <= chunk.length - 5; i++) {
      if (chunk[i] == 0xFF &&
          chunk[i + 1] == 0x55 &&
          chunk[i + 2] == 0xAA &&
          chunk[i + 3] == 0x00 &&
          chunk[i + 4] == XyrixCommands.commandAck) {
        endIdx = i;
        break;
      }
    }
    if (endIdx < 0) {
      _fileListRaw.add(chunk);
      _rxBuffer = Uint8List(0);
      // 兜底：结束帧丢失时防止无限累积
      if (_fileListRaw.length > 512 * 1024) {
        _finishFileList();
      }
      return;
    }
    if (endIdx > 0) {
      _fileListRaw.add(chunk.sublist(0, endIdx));
    }
    _finishFileList();
    // 结束帧之后若还有数据，交回正常帧解析
    final tail = Uint8List.fromList(Uint8List.sublistView(chunk, endIdx));
    final (frames, rest) = XyrixFrameCodec.decode(tail);
    _rxBuffer = rest.length > 4096 ? Uint8List(0) : rest;
    for (final frame in frames) {
      _dispatchFrame(frame);
    }
  }

  /// 解析收集到的明文并发布文件列表
  void _finishFileList() {
    _collectingFileList = false;
    final text = utf8.decode(_fileListRaw.takeBytes(), allowMalformed: true);
    final files = <RecordingFile>[];
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) continue;
      final parsed = XyrixFrameCodec.parseFileListLine(line);
      if (parsed == null) {
        debugPrint('[Xyrix] 文件列表出现无法解析的行: ${line.trim()}');
        continue;
      }
      final path = parsed.path;
      final name = path.startsWith('0:/') ? path.substring(3) : path;
      files.add(RecordingFile(
        sn: files.length,
        name: name,
        sizeBytes: parsed.sizeBytes,
        startTime: _parseFileNameTime(name),
      ));
    }
    debugPrint('[Xyrix] 文件列表解析完成：${files.length} 个文件');
    _lastFileList = files;
    _emit(FileListEvent(files));
    final completer = _fileListCompleter;
    _fileListCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(files);
    }
  }

  /// 文件名形如 `2026-09-21-09-57-34.wav`，内嵌录音开始时间
  DateTime? _parseFileNameTime(String name) {
    final m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-(\d{2})',
    ).firstMatch(name);
    if (m == null) return null;
    return DateTime.tryParse(
        '${m[1]}-${m[2]}-${m[3]} ${m[4]}:${m[5]}:${m[6]}');
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
      case XyrixCommands.fileList:
        // 响应为 `FF 55 AA 00 05 + 明文行 + FF 55 AA 00 2F`（联调实测），
        // 自本帧起进入明文收集，结束帧到达后统一解析
        _collectingFileList = true;
        _fileListRaw.clear();
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
    await sendCommand(XyrixCommands.recordStart);
    // 厂商协议无命令确认帧：GATT 写入成功即视为已生效（录音中设备会直接
    // 开始推送数据流），否则 UI 永远等不到状态回调
    _emit(RecordStateEvent(RecordState.recording));
  }

  @override
  Future<void> pauseRecord() async {
    await sendCommand(XyrixCommands.recordPause);
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
    _emit(RecordStateEvent(RecordState.idle));
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
    // TODO(厂商确认)：杰理/Telink 双芯片分支与数据包流解析
    await sendCommand(
        XyrixCommands.transferPrepareJl, XyrixFrameCodec.pathData(file.name));
    await sendCommand(XyrixCommands.transferStartJl);
  }

  @override
  Future<void> cancelDownload() => sendCommand(XyrixCommands.bleTransferStop);

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
    await _scanSub?.cancel();
    await _connSub?.cancel();
    await _notifySub?.cancel();
    await _events.close();
  }
}

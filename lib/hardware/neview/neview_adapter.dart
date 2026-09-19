/// Neview (NVEasy) 适配器。
///
/// 包装现有 `NvEasyPlugin` 原生通道：订阅其原始事件广播并翻译为统一
/// [HardwareEvent]。不依赖 DtingStore / GetX，可独立测试。
library;

import 'dart:async';

import 'package:dting/hardware/ble_device_adapter.dart';
import 'package:dting/hardware/hardware_event.dart';
import 'package:dting/hardware/models.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';

class NeviewAdapter extends BleDeviceAdapter {
  final StreamController<HardwareEvent> _events =
      StreamController<HardwareEvent>.broadcast();

  StreamSubscription<NvRawEvent>? _rawSub;

  /// 已处理的导入文件 key（fileSn / 路径），防止 BLE 与 WiFi 完成事件重复导入
  final Set<String> _processedImports = {};

  /// 下载进度节流用：保留最近一次进度，速度事件到来时合并发出
  TransferProgress _lastProgress = const TransferProgress();

  @override
  String get vendorId => HardwareVendor.neview;

  @override
  String get vendorDisplayName => 'Neview';

  @override
  CapabilityManifest get capabilities => const CapabilityManifest({
        HardwareCapability.pauseResume,
        HardwareCapability.wifiTransfer,
        HardwareCapability.firmwareUpgrade,
        // addMark / deleteFile / liveAudio：现有原生通道未暴露，见各方法 TODO
      });

  @override
  Stream<HardwareEvent> get events => _events.stream;

  /// 接入原始事件流。App 启动时（NvEasyPlugin.init 之后）调用一次。
  void attach() {
    _rawSub ??= NvEasyPlugin.rawEvents.listen(_onRawEvent);
  }

  @override
  Future<void> dispose() async {
    await _rawSub?.cancel();
    _rawSub = null;
    await _events.close();
  }

  // ------------------------------------------------------------------
  // 原始事件 -> 统一事件
  // ------------------------------------------------------------------

  void _emit(HardwareEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  void _onRawEvent(NvRawEvent e) {
    final data = e.data;
    switch (e.type) {
      case 'didDiscover':
        _emit(DeviceDiscoveredEvent(DiscoveredDevice(
          vendorId: vendorId,
          deviceId: '${data?['uuid'] ?? ''}',
          name: '${data?['name'] ?? ''}',
          rssi: 0,
        )));
        break;
      case 'didConnect':
        _emit(ConnectionStateEvent('${data?['uuid'] ?? ''}',
            ConnectionPhase.connected));
        break;
      case 'didFailConnect':
        _emit(ConnectionStateEvent(
          '${data?['uuid'] ?? ''}',
          ConnectionPhase.disconnected,
          errorMessage: 'connect failed',
        ));
        break;
      case 'didDisconnect':
        _emit(ConnectionStateEvent(
          '${data?['uuid'] ?? ''}',
          ConnectionPhase.disconnected,
        ));
        break;
      case 'didReceiveAuthsn':
        _emit(DeviceInfoEvent(DeviceHardwareInfo(
          serialNumber: data?['sn']?.toString(),
        )));
        break;
      case 'didUpdateBattery':
        final battery = int.tryParse('${data?['caseBattery'] ?? ''}') ?? 0;
        _emit(BatteryEvent(BatteryStatus(levelPercent: battery)));
        break;
      case 'didReceiveFiles':
        _emit(FileListEvent(_parseFiles(data)));
        break;
      case 'didUpdateMeetingType':
        final mode = data?['mode'];
        _emit(RecordSceneEvent(mode == 1 ? RecordScene.call : RecordScene.meeting));
        break;
      case 'didUpdateDeviceRecordStatus':
      case 'sendRecordStatus':
        final status = data?['status'];
        final scene = data?['mode'] == 1 ? RecordScene.call : RecordScene.meeting;
        _emit(RecordStateEvent(
          status == 1 ? RecordState.recording : RecordState.idle,
          scene: scene,
        ));
        break;
      case 'didReceiveRecordMP3FilePath':
      case 'wifiDidGetFile':
      case 'wifiDidGetMP3File':
        final imported = _parseImport(data);
        if (imported != null) {
          _emit(FileImportedEvent(imported));
        }
        break;
      case 'didUpdateDownloadFileProgress':
        _lastProgress = TransferProgress(
          state: TransferState.transferring,
          currentPacket: (data?['currentPacket'] as num?)?.toInt() ?? 0,
          totalPacket: (data?['totalPacket'] as num?)?.toInt() ?? 1,
          currentFileIndex: (data?['currentNumber'] as num?)?.toInt() ?? 0,
          speedKbps: _lastProgress.speedKbps,
        );
        _emit(TransferProgressEvent(_lastProgress));
        break;
      case 'didUpdateDownloadFileState':
        final downloading = data?['isDownloading'] == 1;
        _emit(TransferProgressEvent(TransferProgress(
          state: downloading ? TransferState.transferring : TransferState.idle,
          speedKbps: _lastProgress.speedKbps,
        )));
        break;
      case 'fileDownloadSpeed':
        _lastProgress = TransferProgress(
          state: _lastProgress.state,
          currentPacket: _lastProgress.currentPacket,
          totalPacket: _lastProgress.totalPacket,
          currentFileIndex: _lastProgress.currentFileIndex,
          speedKbps: (data?['speedKbps'] as num?)?.toInt() ?? 0,
        );
        _emit(TransferProgressEvent(_lastProgress));
        break;
      case 'deviceVersion':
        _emit(DeviceInfoEvent(DeviceHardwareInfo(
          firmwareVersion: data?['softwareVersion']?.toString(),
          hardwareVersion: data?['hardwareVersion']?.toString(),
        )));
        break;
      case 'deviceUpdateOtaStatus':
        _emit(_parseOta(data));
        break;
      case 'deviceWifiStatus':
        final status = data is int ? data : int.tryParse('$data');
        if (status != null && status >= 0 && status <= 5) {
          _emit(WifiStatusEvent(WifiTransferStatus.values[status]));
        }
        break;
      case 'blueTurnOff':
        _emit(const BluetoothOffEvent());
        break;
      case 'error':
        _emit(HardwareErrorEvent(HardwareErrorCode.deviceError, '$data'));
        break;
      default:
        break;
    }
  }

  List<RecordingFile> _parseFiles(dynamic data) {
    final files = <RecordingFile>[];
    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          files.add(RecordingFile(
            sn: int.tryParse('${item['sn']}') ?? 0,
            name: '${item['name'] ?? ''}',
            sizeBytes: int.tryParse('${item['size'] ?? 0}') ?? 0,
            scene: '${item['scene']}' == '1'
                ? RecordScene.call
                : RecordScene.meeting,
            startTime: _epochToDateTime(item['startTimestamp']),
            endTime: _epochToDateTime(item['endTimestamp']),
          ));
        }
      }
    }
    return files;
  }

  ImportedRecording? _parseImport(dynamic data) {
    if (data is! Map) return null;
    final path = data['fileMp3Path']?.toString();
    final fileSn = (data['fileSN'] as num?)?.toInt();
    final key = fileSn != null ? 'fileSn_$fileSn' : (path ?? '');
    if (key.isEmpty || _processedImports.contains(key)) {
      return null;
    }
    if (path == null || path.isEmpty) return null;
    _processedImports.add(key);
    if (_processedImports.length > 64) {
      _processedImports.remove(_processedImports.first);
    }
    return ImportedRecording(
      filePath: path,
      recordStartTime: DateTime.tryParse('${data['recordStartTime'] ?? ''}'),
      durationMs: (data['fileDuration'] as num?)?.toInt(),
      fileSn: fileSn,
      scene: '${data['scene']}' == '1' ? RecordScene.call : RecordScene.meeting,
    );
  }

  FirmwareEvent _parseOta(dynamic data) {
    final status = (data?['status'] as num?)?.toInt() ?? -1;
    final progress = (data?['progress'] as num?)?.toInt() ?? 0;
    switch (status) {
      case 0:
        return const FirmwareEvent(FirmwareState.started);
      case 1:
        return FirmwareEvent(FirmwareState.progress,
            progressPercent: progress,
            upgradedBytes: (data?['upgradedSize'] as num?)?.toInt());
      case 2:
        return const FirmwareEvent(FirmwareState.success, progressPercent: 100);
      default:
        return FirmwareEvent(FirmwareState.failed,
            error: data?['error']?.toString() ?? 'ota failed');
    }
  }

  DateTime? _epochToDateTime(dynamic seconds) {
    final s = int.tryParse('$seconds');
    if (s == null || s <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      s > 1 << 34 ? s : s * 1000,
    );
  }

  // ------------------------------------------------------------------
  // BleDeviceAdapter 接口
  // ------------------------------------------------------------------

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    _emit(const ScanStateEvent(true));
    await NvEasyPlugin().startScan();
  }

  @override
  Future<void> stopScan() async {
    await NvEasyPlugin().stopScan();
    _emit(const ScanStateEvent(false));
  }

  @override
  Future<void> connect(DiscoveredDevice device, {String? authKey}) async {
    _connectedDeviceId = device.deviceId;
    // AppKey（16 位厂商码）由原生侧读取/内置；如需动态下发，
    // TODO(原生): startConnect 通道增加 appKey 参数并设置 manufacturerCode。
    await NvEasyPlugin().startConnect(device.deviceId);
  }

  @override
  Future<void> disconnect() async {
    final id = _connectedDeviceId;
    if (id != null && id.isNotEmpty) {
      await NvEasyPlugin().startDisconnect(id);
    }
  }

  String? _connectedDeviceId;

  @override
  Future<void> queryDeviceInfo() async {
    // 原生约束：设备信息查询需串行，否则数据通道阻塞（见基座 store 注释）
    await NvEasyPlugin().getBattery();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await NvEasyPlugin().queryVersion();
  }

  @override
  Future<void> startRecord(RecordScene mode) async {
    await NvEasyPlugin().initOpus(true); // 单声道 16k
    await NvEasyPlugin().startRecord();
  }

  @override
  Future<void> pauseRecord() => NvEasyPlugin().pauseRecord();

  @override
  Future<void> resumeRecord() => NvEasyPlugin().resumeRecord();

  @override
  Future<void> stopRecord() async {
    final result = await NvEasyPlugin().stopRecord();
    final mp3 = result['mp3Path'];
    if (mp3 != null && mp3.isNotEmpty) {
      final imported = ImportedRecording(filePath: mp3);
      if (!_processedImports.contains(mp3)) {
        _processedImports.add(mp3);
        _emit(FileImportedEvent(imported));
      }
    }
  }

  @override
  Future<void> addMark() async {
    // TODO(原生): NVEasySDK 有 recMark()，需在插件通道补 recMark 方法后接入。
    throw HardwareException(
      HardwareErrorCode.unsupportedCapability,
      'Neview 插件通道暂未实现 recMark',
    );
  }

  @override
  Future<List<RecordingFile>> listFiles() async {
    final Completer<List<RecordingFile>> completer = Completer();
    late final StreamSubscription<HardwareEvent> sub;
    sub = events.listen((event) {
      if (event is FileListEvent && !completer.isCompleted) {
        completer.complete(event.files);
      }
    });
    try {
      await NvEasyPlugin().getFileList();
      return await completer.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw HardwareException(HardwareErrorCode.deviceError, '获取文件列表超时');
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> downloadFile(
    RecordingFile file, {
    TransferTransport transport = TransferTransport.wifi,
    bool autoDelete = false,
  }) async {
    // TODO(原生): 下载通道补充 autoDelete 透传。
    if (transport == TransferTransport.wifi &&
        capabilities.supports(HardwareCapability.wifiTransfer)) {
      await NvEasyPlugin().downLoadFileWifi(file.sn);
    } else {
      await NvEasyPlugin().downLoadFile(file.sn);
    }
  }

  @override
  Future<void> cancelDownload() async {
    // TODO(原生): 通道未暴露取消下载，需要原生补充。
    throw HardwareException(
      HardwareErrorCode.unsupportedCapability,
      'Neview 插件通道暂未实现取消下载',
    );
  }

  @override
  Future<void> deleteFile(RecordingFile file) async {
    // TODO(原生): NVEasySDK 有 delfile(sn:name:)，需在插件通道补 delfile 方法后接入。
    throw HardwareException(
      HardwareErrorCode.unsupportedCapability,
      'Neview 插件通道暂未实现删除设备文件',
    );
  }

  @override
  Future<void> upgradeFirmware({
    required String filePath,
    required String newVersion,
  }) async {
    await NvEasyPlugin().otaUpgrade(filePath, newVersion);
  }
}

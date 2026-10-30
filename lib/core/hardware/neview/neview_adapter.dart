/// Neview (NVEasy) 适配器。
///
/// 包装现有 `NvEasyPlugin` 原生通道：订阅其原始事件广播并翻译为统一
/// [HardwareEvent]。不依赖 DtingStore / GetX，可独立测试。
library;

import 'dart:async';

import 'package:dting/core/hardware/ble_device_adapter.dart';
import 'package:dting/core/hardware/command_lane.dart';
import 'package:dting/core/hardware/hardware_event.dart';
import 'package:dting/core/hardware/models.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';

class NeviewAdapter extends BleDeviceAdapter {
  final StreamController<HardwareEvent> _events =
      StreamController<HardwareEvent>.broadcast();

  StreamSubscription<NvRawEvent>? _rawSub;

  /// 已处理的导入文件 key（fileSn / 路径），防止 BLE 与 WiFi 完成事件重复导入
  final Set<String> _processedImports = {};

  /// 下载进度节流用：保留最近一次进度，速度事件到来时合并发出
  TransferProgress _lastProgress = const TransferProgress();

  /// 发往卡片的命令一律走这条车道：**上一条收到回包/超时之后才发下一条**。
  ///
  /// 厂商 AAR 的方法（`startRecord`/`stopRecord`/…）在**下发后立刻**返回，
  /// 真正的应答从事件流回来；所以车道卡的是「这条命令自己何时算结束」：
  ///  * 有回包语义的（`listFiles` 等在方法内部等事件、手写那条按 `*DEV#<cmd>#` 配对）
  ///    —— 方法 future 完成才是真的收到应答；
  ///  * 只有下发没有回包语义的（`startRecord`/`pauseRecord`/`stopRecord`/`addMark`/
  ///    `downloadFile` 的起手）—— future 只代表写进去了，车道保证的是
  ///    **不并发**，不是「等到设备点头」。真有回包要求的命令必须在方法内部等事件。
  final CommandLane commandLane = CommandLane(label: 'neview');

  @override
  String get vendorId => HardwareVendor.neview;

  @override
  String get vendorDisplayName => 'Neview';

  @override
  CapabilityManifest get capabilities => const CapabilityManifest({
        // 真机验证且通道已接通的两项（2026-10-23，Lynse AI 0091 proto 24）：
        // record(dev,2/3,mode) 都有 onRecordExtended 回包；recordMark 回 status=0。
        HardwareCapability.pauseResume,
        HardwareCapability.addMark,
        // ⚠️ 有意**不声明**下面两项，它们之前是空头承诺：
        //  - wifiTransfer：三轮真机扫档都不通（autoConnect=true 停在 CONNECTING；
        //    autoConnect=false 时设备根本不回报 onWifiOpened 凭据）。
        //    厂商答清「开热点后是否回 *DEV#wifi#…# / 要不要先写凭证」之前不给。
        //  - firmwareUpgrade：没有可用固件包，从未验证过（刷坏会变砖），不给。
        //  - deleteFile：原生通道已接通，但删除不可逆且未真机验证，不给。
        //  - liveAudio：设备侧已验通（onStream 881 帧/70,480 B），
        //    但 BleDeviceAdapter 契约上没有对应的取流方法，声明了上层也拿不到，
        //    先不声明；等契约补上音频帧通道再开（见 lynse-hardware-sdk 的 audio.live）。
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
    // AppKey 必须真的传到厂商 SDK：v1.2.0 起 init 缺 appKey 时，
    // 设备对任何 *APP# 命令都保持沉默（2026-10-23 真机对照）。
    // authKey 为空时原生侧回落到 MMKV 里持久化的 neview_appkey。
    await NvEasyPlugin().startConnect(device.deviceId, appKey: authKey);
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
    // 原生约束：设备信息查询需串行，否则数据通道阻塞（见基座 store 注释）。
    // 现在整条链路都走车道，这里只是把两条命令捆成一段原子操作。
    await commandLane.run('queryDeviceInfo', () async {
      await NvEasyPlugin().getBattery();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await NvEasyPlugin().queryVersion();
    });
  }

  @override
  Future<void> startRecord(RecordScene mode) async {
    await commandLane.run('startRecord', () async {
      await NvEasyPlugin().initOpus(true); // 单声道 16k
      await NvEasyPlugin().startRecord();
    });
  }

  @override
  Future<void> pauseRecord() =>
      commandLane.run('pauseRecord', () => NvEasyPlugin().pauseRecord());

  @override
  Future<void> resumeRecord() =>
      commandLane.run('resumeRecord', () => NvEasyPlugin().resumeRecord());

  @override
  Future<void> stopRecord() async {
    // 记这一刻：真机上刚录完的音约 5 s 后才进文件列表（见 listFiles 的重问逻辑）
    _lastStopAt = DateTime.now();
    final result = await commandLane.run('stopRecord', () => NvEasyPlugin().stopRecord());
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
    // 真机验证过：recordMark → onRecordMark status=0（含 index 与不含暂停的 offset ms）
    await commandLane.run('addMark', () => NvEasyPlugin().addMark());
  }

  /// 上一次看到的文件条数（-1 = 还没列过）
  int _lastFileCount = -1;

  /// 最近一次停止录音的时刻；用来触发「新录音延迟可见」的重问。
  DateTime? _lastStopAt;

  @override
  Future<List<RecordingFile>> listFiles() async {
    var files = await _listFilesOnce();
    // 真机行为（2026-10-23，Lynse AI 0091 / proto 24 实测）：
    // `record stop` 之后紧接着列文件，**刚录完那条不在表里**（列表最大 sn=12、
    // 设备当时报的是 sn=13），约 5 s 后重问才出现。
    // 所以「录完立刻列文件」不能拿第一次结果当结论 —— 表现为新录音凭空消失。
    // 这里把重问收在适配器内部，调用方不必知道这个坑；只在停止后 20 s 内、
    // 且条数没有增长时才多问，最多 3 次（每次间隔 5 s），平时不多花一秒。
    final justStopped = _lastStopAt != null &&
        DateTime.now().difference(_lastStopAt!) < const Duration(seconds: 20);
    if (justStopped && _lastFileCount >= 0 && files.length <= _lastFileCount) {
      for (var attempt = 0; attempt < 3; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 5));
        final again = await _listFilesOnce();
        if (again.length > files.length) {
          files = again;
          break;
        }
      }
    }
    _lastFileCount = files.length;
    return files;
  }

  Future<List<RecordingFile>> _listFilesOnce() {
    // 整段进车道：从发出 `getFileList` 到收到 `didReceiveFiles` 算一条命令，
    // 期间不发别的——卡上的列表会话不能被打断（`flist` 之后紧跟着 `listreq`）。
    return commandLane.run('listFiles', () async {
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
    });
  }

  @override
  Future<void> downloadFile(
    RecordingFile file, {
    TransferTransport transport = TransferTransport.ble,
    bool autoDelete = false,
    bool resume = true,
  }) async {
    // TODO(原生): 下载通道补充 autoDelete 透传。
    // 续传由 NvEasyBle AAR 内部按 SN 记偏移，Dart 侧无可用的偏移接口，
    // resume 只作为调用方意图的记录，不影响本通道行为。
    if (transport == TransferTransport.wifi &&
        capabilities.supports(HardwareCapability.wifiTransfer)) {
      await commandLane.run(
          'downloadFile(sn=${file.sn},wifi)', () => NvEasyPlugin().downLoadFileWifi(file.sn));
    } else {
      await commandLane.run(
          'downloadFile(sn=${file.sn},ble)', () => NvEasyPlugin().downLoadFile(file.sn));
    }
  }

  @override
  Future<void> cancelDownload() async {
    // 取消也是一条命令：不能在别的命令正写到一半时插进去（卡上只有一个会话）。
    await commandLane.run('cancelDownload', () => NvEasyPlugin().cancelDownload());
  }

  @override
  Future<void> deleteFile(RecordingFile file) async {
    // 原生通道已接通（deleteRecordFile(sn, name)），但删除不可逆且**没在真机上验过**，
    // 所以这里明确拒绝，而不是「能调通就当已支持」。要开放需先在设备上验一次。
    throw HardwareException(
      HardwareErrorCode.unsupportedCapability,
      'Neview 删除设备文件：通道已接通但未真机验证，故意不开放',
    );
  }

  @override
  Future<void> upgradeFirmware({
    required String filePath,
    required String newVersion,
  }) async {
    await commandLane.run('upgradeFirmware', () => NvEasyPlugin().otaUpgrade(filePath, newVersion));
  }
}

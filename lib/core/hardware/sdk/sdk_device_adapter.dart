import 'dart:async';
import 'dart:io';

import 'package:dting/core/hardware/ble_device_adapter.dart';
import 'package:dting/core/hardware/hardware_event.dart';
import 'package:dting/core/hardware/models.dart';
import 'package:dting/core/hardware/sdk/hardware_permissions.dart';
import 'package:dting/core/hardware/sdk/sdk_hardware_runtime.dart';
import 'package:dting/core/hardware/xyrix/xyrix_opus_muxer.dart';
import 'package:flutter/foundation.dart';
import 'package:lynse_hardware_contract/lynse_hardware.dart' as sdk;

/// 把统一 SDK 的会话翻译成 App 既有的 [BleDeviceAdapter] 事件/接口。
///
/// 这样 UI 与 `DeviceSessionController` 不需要知道任何厂商类型；
/// 旧的双 Dart 适配器仍然保留，可用 `USE_SDK_HARDWARE=false` 回退。
class SdkDeviceAdapter implements BleDeviceAdapter {
  SdkDeviceAdapter({
    required this.vendorId,
    required this.adapterId,
    required SdkHardwareRuntime runtime,
  }) : _runtime = runtime;

  @override
  final String vendorId;

  /// SDK adapterId，如 `com.lynse.protocol.newview`。
  final String adapterId;
  final SdkHardwareRuntime _runtime;

  final StreamController<HardwareEvent> _events =
      StreamController<HardwareEvent>.broadcast();
  final List<StreamSubscription<dynamic>> _sessionSubscriptions = [];
  StreamSubscription<sdk.DiscoveryEvent>? _scanSubscription;
  Timer? _scanTimer;
  sdk.DeviceSession? _session;
  CapabilityManifest _capabilities = const CapabilityManifest({});

  final Map<int, sdk.RecordingFile> _sdkFilesBySn = {};
  final Map<String, int> _snByFileId = {};
  _ActiveTransfer? _activeTransfer;
  RecordScene _scene = RecordScene.unknown;

  @override
  String get vendorDisplayName =>
      vendorId == HardwareVendor.neview ? 'Neview' : 'Xyrix';

  @override
  CapabilityManifest get capabilities => _capabilities;

  @override
  Stream<HardwareEvent> get events => _events.stream;

  // ------------------------------------------------------------------
  // 扫描 / 连接
  // ------------------------------------------------------------------

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    await HardwarePermissions.requestBluetooth();
    await stopScan();
    final hardware = await _runtime.ensureInitialized(appKey: '');
    _emit(const ScanStateEvent(true));
    _scanSubscription = hardware
        .discover(sdk.DiscoveryOptions(timeout: timeout))
        .listen(
      (event) {
        if (event.isLost) return;
        if (event.device.adapterId != adapterId) return;
        _emit(DeviceDiscoveredEvent(_toAppDevice(event.device)));
      },
      onError: (Object error) {
        _scanTimer?.cancel();
        _emit(ScanStateEvent(false));
        _emit(HardwareErrorEvent(HardwareErrorCode.unknown, '$error'));
      },
      onDone: () {
        _scanTimer?.cancel();
        _emit(const ScanStateEvent(false));
      },
      cancelOnError: false,
    );
    // 桥接层的 discovery 没有 onDone 回调；UI 不能永远停在“正在扫描”。
    _scanTimer?.cancel();
    _scanTimer = Timer(timeout, () {
      stopScan();
    });
  }

  @override
  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    final subscription = _scanSubscription;
    _scanSubscription = null;
    await subscription?.cancel();
    _emit(const ScanStateEvent(false));
  }

  @override
  Future<void> connect(DiscoveredDevice device, {String? authKey}) async {
    await HardwarePermissions.requestBluetooth();
    await stopScan();
    if (_session != null) await disconnect();

    final hardware = await _runtime.ensureInitialized(appKey: authKey ?? '');
    _emit(ConnectionStateEvent(device.deviceId, ConnectionPhase.connecting));
    sdk.DeviceSession session;
    try {
      session = await hardware.connect(
        sdk.DeviceId(device.deviceId),
        const sdk.ConnectOptions(autoReconnect: true),
      );
    } on sdk.LynseException catch (error) {
      // 冷启动自动重连不走扫描，桥接层的 discovery 缓存可能是空的。
      // 做一次有界短扫描，命中同一个 deviceId 再连，不新增 connectById API。
      if (error.code != sdk.LynseErrorCode.invalidState) rethrow;
      await _shortScan(hardware, device.deviceId);
      session = await hardware.connect(
        sdk.DeviceId(device.deviceId),
        const sdk.ConnectOptions(autoReconnect: true),
      );
    }

    _session = session;
    _capabilities = _mapCapabilities(session.capabilities);
    _subscribe(session);
    // Xyrix 的 0x13 对时刚发完时，紧跟着的 0x17 会被卡吞掉；留一个稳定窗口。
    if (vendorId == HardwareVendor.xyrix) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    _emit(ConnectionStateEvent(device.deviceId, ConnectionPhase.connected));
  }

  Future<void> _shortScan(sdk.LynseHardware hardware, String deviceId) async {
    final found = Completer<void>();
    late StreamSubscription<sdk.DiscoveryEvent> subscription;
    subscription = hardware
        .discover(const sdk.DiscoveryOptions(timeout: Duration(seconds: 9)))
        .listen(
      (event) {
        if (!event.isLost &&
            event.device.id.value == deviceId &&
            event.device.adapterId == adapterId &&
            !found.isCompleted) {
          found.complete();
        }
      },
      onError: (Object error) {
        if (!found.isCompleted) found.completeError(error);
      },
      onDone: () {
        if (!found.isCompleted) found.complete();
      },
      cancelOnError: false,
    );
    try {
      await found.future.timeout(const Duration(seconds: 10));
    } finally {
      await subscription.cancel();
    }
  }

  void _subscribe(sdk.DeviceSession session) {
    _sessionSubscriptions.add(
      session.connectionEvents.listen(_onConnectionState),
    );
    _cap<sdk.DeviceInfoCapability>(session);
    final battery = _cap<sdk.BatteryCapability>(session);
    if (battery != null) {
      _sessionSubscriptions.add(battery.batteryEvents.listen((value) {
        _emit(BatteryEvent(
          BatteryStatus(
            levelPercent: value.levelPercent,
            isCharging: value.isCharging,
          ),
        ));
      }));
    }
    final recording = _cap<sdk.RecordingControlCapability>(session);
    if (recording != null) {
      _sessionSubscriptions.add(recording.stateEvents.listen((state) {
        _emit(RecordStateEvent(
          _toAppRecordState(state),
          scene: _scene,
        ));
      }));
    }
    final transfer = _cap<sdk.FileTransferCapability>(session);
    if (transfer != null) {
      _sessionSubscriptions.add(transfer.transferEvents.listen(_onTransferEvent));
    }
    final live = _cap<sdk.LiveAudioCapability>(session);
    if (live != null) {
      _sessionSubscriptions.add(live.frames.listen(_onAudioFrame));
    }
    final hardware = _sessionHardware(session);
    if (hardware != null) {
      _sessionSubscriptions.add(hardware.events.listen((event) {
        if (event.sessionId.value != session.id.value) return;
        if (event.kind == sdk.HardwareEventKind.networkRestoreRequired) {
          _emit(HardwareErrorEvent(
            HardwareErrorCode.connectionLost,
            event.message ?? '手机网络需要恢复',
          ));
        } else if (event.kind == sdk.HardwareEventKind.diagnostic &&
            event.message != null) {
          debugPrint('[LynseSDK] ${event.message}');
        }
      }));
    }
  }

  void _onConnectionState(sdk.ConnectionState state) {
    final deviceId = _session?.deviceId.value ?? '';
    switch (state) {
      case sdk.ConnectionState.disconnected:
        _emit(ConnectionStateEvent(deviceId, ConnectionPhase.disconnected));
        _clearSession();
      case sdk.ConnectionState.connecting:
      case sdk.ConnectionState.reconnecting:
        _emit(ConnectionStateEvent(deviceId, ConnectionPhase.connecting));
      case sdk.ConnectionState.connected:
        _emit(ConnectionStateEvent(deviceId, ConnectionPhase.connected));
      case sdk.ConnectionState.disconnecting:
        _emit(ConnectionStateEvent(deviceId, ConnectionPhase.disconnected));
    }
  }

  @override
  Future<void> disconnect() async {
    final session = _session;
    final hardware = session == null ? null : _sessionHardware(session);
    _clearSession();
    if (session != null) {
      try {
        await hardware?.disconnect(session.id);
      } catch (error) {
        debugPrint('[LynseSDK] disconnect failed: $error');
      }
    }
  }

  void _clearSession() {
    for (final subscription in _sessionSubscriptions) {
      subscription.cancel();
    }
    _sessionSubscriptions.clear();
    _session = null;
    _capabilities = const CapabilityManifest({});
    final active = _activeTransfer;
    if (active != null) {
      final last = active.lastEvent;
      _emit(TransferProgressEvent(
        TransferProgress(
          state: TransferState.cancelled,
          currentPacket: ((last?.transferredBytes ?? 0) / 512).ceil(),
          totalPacket: ((last?.totalBytes ?? active.sdkFile.sizeBytes) / 512).ceil(),
          receivedBytes: last?.transferredBytes,
          totalBytes: last?.totalBytes ?? active.sdkFile.sizeBytes,
        ),
        fileSn: active.appFile.sn,
      ));
      active.cancel();
    }
    _activeTransfer = null;
  }

  @override
  Future<void> queryDeviceInfo() async {
    final session = _session;
    if (session == null) return;
    try {
      final info = await _cap<sdk.DeviceInfoCapability>(session)?.readDeviceInfo();
      if (info != null) {
        _emit(DeviceInfoEvent(DeviceHardwareInfo(
          firmwareVersion: info.firmwareVersion,
          serialNumber: info.serialNumber,
        )));
      }
      final battery = await _cap<sdk.BatteryCapability>(session)?.readBattery();
      if (battery != null) {
        _emit(BatteryEvent(BatteryStatus(
          levelPercent: battery.levelPercent,
          isCharging: battery.isCharging,
        )));
      }
    } on sdk.LynseException catch (error) {
      _emit(HardwareErrorEvent(_mapError(error.code), error.message));
    }
  }

  // ------------------------------------------------------------------
  // 录音
  // ------------------------------------------------------------------

  @override
  Future<void> startRecord(RecordScene mode) async {
    final recording = _requireCapability<sdk.RecordingControlCapability>();
    _scene = mode;
    await _sdkCall(
      () => recording.start(mode: mode == RecordScene.call ? 1 : 0),
      'startRecording',
    );
    _emit(RecordSceneEvent(mode));
  }

  @override
  Future<void> pauseRecord() => _sdkCall(
        () => _requireCapability<sdk.RecordingControlCapability>().pause(),
        'pauseRecording',
      );

  @override
  Future<void> resumeRecord() => _sdkCall(
        () => _requireCapability<sdk.RecordingControlCapability>().resume(),
        'resumeRecording',
      );

  @override
  Future<void> stopRecord() => _sdkCall(
        () => _requireCapability<sdk.RecordingControlCapability>().stop(),
        'stopRecording',
      );

  @override
  Future<void> addMark() => _sdkCall(
        () => _requireCapability<sdk.RecordingControlCapability>().addMark(),
        'addRecordingMark',
      );

  // ------------------------------------------------------------------
  // 文件
  // ------------------------------------------------------------------

  @override
  Future<List<RecordingFile>> listFiles() async {
    final storage = _requireCapability<sdk.FileStorageCapability>();
    final files = await _sdkCall(storage.listFiles, 'listFiles');
    final mapped = files.map(_toAppFile).toList(growable: false);
    _emit(FileListEvent(mapped));
    return mapped;
  }

  @override
  Future<void> downloadFile(
    RecordingFile file, {
    TransferTransport transport = TransferTransport.ble,
    bool autoDelete = false,
    bool resume = true,
  }) async {
    final session = _session;
    if (session == null) {
      throw HardwareException(HardwareErrorCode.connectionLost, '设备未连接');
    }
    final sdkFile = _sdkFilesBySn[file.sn];
    if (sdkFile == null) {
      throw HardwareException(HardwareErrorCode.deviceError, '设备文件列表已失效，请刷新');
    }
    final transfer = _requireCapability<sdk.FileTransferCapability>();
    try {
      if (transport == TransferTransport.wifi) {
        await HardwarePermissions.requestWifi();
        await _downloadWifi(transfer, sdkFile, file, resume: resume);
      } else {
        await _downloadBle(transfer, sdkFile, file);
      }
    } on sdk.LynseException catch (error) {
      throw HardwareException(_mapError(error.code), error.message);
    }
  }

  Future<void> _downloadBle(
    sdk.FileTransferCapability transfer,
    sdk.RecordingFile sdkFile,
    RecordingFile appFile,
  ) async {
    final paths = _pathsFor(sdkFile);
    final active = _ActiveTransfer(
      appFile: appFile,
      sdkFile: sdkFile,
      useWifi: false,
      oggPath: paths.ogg,
      partPath: paths.part,
      rawPath: paths.raw,
    );
    active.sink = _BleFileSink(
      oggPath: paths.ogg,
      partPath: paths.part,
      wavPath: paths.wav,
    );
    _activeTransfer = active;
    try {
      final handle = await transfer.download(
        sdkFile.id,
        options: const sdk.TransferOptions(
          policy: sdk.TransferPolicy.bleOnly,
          verifyChecksum: true,
        ),
      );
      active.transferId = handle.transferId;
      final terminal = await active.done.future.timeout(
        const Duration(minutes: 10),
      );
      if (terminal == _Terminal.cancelled) {
        await active.sink?.finish(false);
        return;
      }
      if (terminal != _Terminal.completed) {
        await active.sink?.finish(false);
        throw HardwareException(
          HardwareErrorCode.transferInterrupted,
          active.errorMessage ?? '传输未完成',
        );
      }
      final event = active.lastEvent;
      final integrity = _integrity(sdkFile, event, event?.transferredBytes ?? 0);
      if (integrity == TransferIntegrity.sizeMismatch) {
        await active.sink?.finish(false);
        _emit(FileImportedEvent(_rejected(appFile, sdkFile, integrity, event)));
        throw HardwareException(HardwareErrorCode.integrityMismatch, '文件校验未通过');
      }
      final saved = await active.sink?.finish(true);
      if (saved == null) {
        throw HardwareException(HardwareErrorCode.transferInterrupted, '没有收到可用的音频包');
      }
      _emit(FileImportedEvent(_imported(
        saved.path,
        appFile,
        sdkFile,
        integrity,
        event?.transferredBytes ?? 0,
      )));
    } finally {
      if (identical(_activeTransfer, active)) _activeTransfer = null;
    }
  }

  Future<void> _downloadWifi(
    sdk.FileTransferCapability transfer,
    sdk.RecordingFile sdkFile,
    RecordingFile appFile, {
    required bool resume,
  }) async {
    final paths = _pathsFor(sdkFile);
    final finalFile = File(paths.raw);
    final partial = File('${paths.raw}.part');
    // 上一次完整落盘的文件不复用；断点只认 .part，且大小必须 <= 文件大小。
    if (await finalFile.exists()) await finalFile.delete();
    if (!resume && await partial.exists()) await partial.delete();
    var resumeOffset = 0;
    if (resume && await partial.exists()) {
      resumeOffset = await partial.length();
      if (resumeOffset <= 0 || resumeOffset >= sdkFile.sizeBytes) {
        await partial.delete();
        resumeOffset = 0;
      }
    }
    final active = _ActiveTransfer(
      appFile: appFile,
      sdkFile: sdkFile,
      useWifi: true,
      oggPath: paths.ogg,
      partPath: paths.part,
      rawPath: paths.raw,
    );
    _activeTransfer = active;
    try {
      final handle = await transfer.download(
        sdkFile.id,
        options: sdk.TransferOptions(
          policy: sdk.TransferPolicy.wifiOnly,
          resumeOffsetBytes: resumeOffset,
          verifyChecksum: true,
          destinationPath: paths.raw,
        ),
      );
      active.transferId = handle.transferId;
      final terminal = await active.done.future.timeout(
        const Duration(minutes: 10),
      );
      final event = active.lastEvent;
      final raw = File(event?.savedPath ?? paths.raw);
      if (terminal == _Terminal.cancelled) {
        if (await raw.exists()) await raw.delete();
        return;
      }
      if (terminal != _Terminal.completed) {
        if (await raw.exists()) await raw.delete();
        throw HardwareException(
          HardwareErrorCode.transferInterrupted,
          active.errorMessage ?? '快传未完成',
        );
      }
      final rawBytes = await raw.exists() ? await raw.length() : 0;
      final integrity = _integrity(
        sdkFile,
        event,
        event?.transferredBytes ?? rawBytes,
      );
      if (integrity == TransferIntegrity.sizeMismatch || !await raw.exists()) {
        if (await raw.exists()) await raw.delete();
        _emit(FileImportedEvent(_rejected(appFile, sdkFile, integrity, event)));
        throw HardwareException(HardwareErrorCode.integrityMismatch, '文件校验未通过');
      }
      final wav = await _isDeviceWrittenFile(raw.path);
      final File saved;
      if (wav) {
        // 设备自己写好了整个文件：快传收到的原始流就是文件本身，
        // 再按 Opus 容器切一遍只会把它读坏。
        final destination = File(paths.wav);
        if (await destination.exists()) await destination.delete();
        saved = await raw.rename(destination.path);
      } else {
        saved = await _convertRawToOgg(sdkFile, raw.path, paths.ogg);
        if (await raw.exists()) await raw.delete();
      }
      _emit(FileImportedEvent(_imported(
        saved.path,
        appFile,
        sdkFile,
        integrity,
        event?.transferredBytes ?? rawBytes,
      )));
    } finally {
      if (identical(_activeTransfer, active)) _activeTransfer = null;
    }
  }

  @override
  Future<void> cancelDownload() async {
    final active = _activeTransfer;
    final transfer = _session == null
        ? null
        : _cap<sdk.FileTransferCapability>(_session!);
    if (active?.transferId != null && transfer != null) {
      await _sdkCall(() => transfer.cancel(active!.transferId!), 'cancelTransfer');
    }
    active?.cancel();
  }

  @override
  Future<void> deleteFile(RecordingFile file) async {
    throw HardwareException(
      HardwareErrorCode.unsupportedCapability,
      '本轮 SDK 不声明设备文件删除（不可逆）',
    );
  }

  @override
  Future<void> upgradeFirmware({
    required String filePath,
    required String newVersion,
  }) async {
    throw HardwareException(
      HardwareErrorCode.unsupportedCapability,
      '本轮 SDK 不声明固件升级（无可用固件包）',
    );
  }

  // ------------------------------------------------------------------
  // 事件翻译
  // ------------------------------------------------------------------

  void _onAudioFrame(sdk.AudioFrame frame) {
    final active = _activeTransfer;
    if (active == null || active.useWifi) return;
    if (frame.transferId != null &&
        active.transferId != null &&
        frame.transferId != active.transferId) {
      return;
    }
    active.sink?.onFrame(frame);
  }

  void _onTransferEvent(sdk.TransferEvent event) {
    final active = _activeTransfer;
    if (active == null || event.fileId != active.sdkFile.id) return;
    if (active.transferId == null) active.transferId = event.transferId;
    if (event.transferId != active.transferId) return;
    active.lastEvent = event;

    final retryableFailure = event.state == sdk.TransferState.failed &&
        active.useWifi &&
        active.rounds < 10 &&
        (event.error?.retryable ?? false);
    if (retryableFailure) {
      active.rounds += 1;
      _resumeWifi(active);
      return;
    }

    _emit(TransferProgressEvent(
      _toAppProgress(event),
      fileSn: active.appFile.sn,
    ));
    final wifiStatus = _toWifiStatus(event.state);
    if (wifiStatus != null) _emit(WifiStatusEvent(wifiStatus));

    switch (event.state) {
      case sdk.TransferState.completed:
        active.finish(_Terminal.completed);
      case sdk.TransferState.cancelled:
        active.finish(_Terminal.cancelled);
      case sdk.TransferState.failed:
        active.errorMessage = event.error?.message ?? '传输失败';
        debugPrint('[LynseSDK] transfer failed: ${active.errorMessage}');
        _emit(HardwareErrorEvent(
          _mapError(event.error?.code ?? sdk.LynseErrorCode.vendorFailure),
          active.errorMessage!,
        ));
        active.finish(_Terminal.failed);
      default:
        break;
    }
  }

  Future<void> _resumeWifi(_ActiveTransfer active) async {
    final transfer = _session == null
        ? null
        : _cap<sdk.FileTransferCapability>(_session!);
    final transferId = active.transferId;
    if (transfer == null || transferId == null) {
      active.errorMessage = '快传续传时会话已失效';
      active.finish(_Terminal.failed);
      return;
    }
    try {
      await transfer.resume(transferId);
    } catch (error) {
      active.errorMessage = '$error';
      active.finish(_Terminal.failed);
    }
  }

  TransferProgress _toAppProgress(sdk.TransferEvent event) {
    final terminal = event.state == sdk.TransferState.completed ||
        event.state == sdk.TransferState.failed ||
        event.state == sdk.TransferState.cancelled;
    return TransferProgress(
      state: switch (event.state) {
        sdk.TransferState.completed => TransferState.completed,
        sdk.TransferState.cancelled => TransferState.cancelled,
        sdk.TransferState.failed => TransferState.failed,
        _ => TransferState.transferring,
      },
      currentFileIndex: 0,
      currentPacket: (event.transferredBytes / 512).ceil(),
      totalPacket: event.totalBytes > 0
          ? (event.totalBytes / 512).ceil()
          : 1,
      speedKbps: event.bytesPerSecond ~/ 1024,
      receivedBytes: event.transferredBytes,
      totalBytes: event.totalBytes,
      integrity: terminal
          ? _integrity(
              _activeTransfer?.sdkFile,
              event,
              event.transferredBytes,
            )
          : null,
    );
  }

  WifiTransferStatus? _toWifiStatus(sdk.TransferState state) => switch (state) {
        sdk.TransferState.preparing ||
        sdk.TransferState.openingDeviceWifi =>
          WifiTransferStatus.opening,
        sdk.TransferState.waitingForPermission ||
        sdk.TransferState.joiningDeviceNetwork ||
        sdk.TransferState.openingDataChannel =>
          WifiTransferStatus.connecting,
        sdk.TransferState.transferring => WifiTransferStatus.connected,
        sdk.TransferState.restoringPhoneNetwork => WifiTransferStatus.stopping,
        sdk.TransferState.completed ||
        sdk.TransferState.failed ||
        sdk.TransferState.cancelled =>
          WifiTransferStatus.stopped,
        _ => null,
      };

  // ------------------------------------------------------------------
  // 映射 / 工具
  // ------------------------------------------------------------------

  CapabilityManifest _mapCapabilities(sdk.CapabilityManifest manifest) {
    bool has(String id, [String? operation]) => manifest.capabilities.any(
          (capability) =>
              capability.id.wireValue == id &&
              (operation == null || capability.operations.contains(operation)),
        );
    final supported = <HardwareCapability>{};
    if (has('recording.control', 'pause') && has('recording.control', 'resume')) {
      supported.add(HardwareCapability.pauseResume);
    }
    if (has('recording.control', 'addMark')) {
      supported.add(HardwareCapability.addMark);
    }
    if (has('audio.live')) supported.add(HardwareCapability.liveAudio);
    if (has('transfer.wifi') &&
        manifest.transferTransports.contains(sdk.TransferTransport.wifi)) {
      supported.add(HardwareCapability.wifiTransfer);
    }
    if (has('firmware.update')) supported.add(HardwareCapability.firmwareUpgrade);
    if (has('storage.files', 'delete')) supported.add(HardwareCapability.deleteFile);
    return CapabilityManifest(supported);
  }

  DiscoveredDevice _toAppDevice(sdk.DiscoveredDevice device) => DiscoveredDevice(
        vendorId: vendorId,
        deviceId: device.id.value,
        name: device.displayName,
        rssi: device.rssi,
      );

  RecordingFile _toAppFile(sdk.RecordingFile file) {
    final sn = _snFor(file);
    _sdkFilesBySn[sn] = file;
    return RecordingFile(
      sn: sn,
      name: file.name,
      sizeBytes: file.sizeBytes,
      scene: RecordScene.unknown,
      startTime: file.createdAt,
      endTime: file.createdAt.add(file.duration),
    );
  }

  int _snFor(sdk.RecordingFile file) {
    final known = _snByFileId[file.id];
    if (known != null) return known;
    final match = RegExp(r'^nv:(\d+):').firstMatch(file.id);
    final sn = int.tryParse(match?.group(1) ?? '') ??
        (1000000 + (file.id.hashCode & 0x3fffffff));
    _snByFileId[file.id] = sn;
    return sn;
  }

  _Paths _pathsFor(sdk.RecordingFile file) {
    final stem = _safeStem(file.name);
    final directory = _runtime.downloadDirectory;
    final base = '${directory.path}/$stem';
    return _Paths(
      ogg: '$base.opus',
      part: '$base.opus.part',
      wav: '$base.wav',
      raw: '$base.raw',
    );
  }

  static String _safeStem(String name) {
    final stem = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    final safe = stem.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_').trim();
    return safe.isEmpty ? 'recording' : safe;
  }

  static bool _asciiAt(Uint8List bytes, int at, String token) {
    if (bytes.length < at + token.length) return false;
    for (var i = 0; i < token.length; i++) {
      if (bytes[at + i] != token.codeUnitAt(i)) return false;
    }
    return true;
  }

  /// 文件头是不是 `RIFF….WAVE`——即设备自己写好的成品文件，不需要再转码。
  static Future<bool> _isDeviceWrittenFile(String path) async {
    final file = File(path);
    final raf = await file.open();
    try {
      if (raf.lengthSync() < 12) return false;
      final head = Uint8List(12);
      await raf.readInto(head, 0, 12);
      return _asciiAt(head, 0, 'RIFF') && _asciiAt(head, 8, 'WAVE');
    } catch (error) {
      debugPrint('[LynseSDK] 读文件头失败: $error');
      return false;
    } finally {
      await raf.close();
    }
  }

  Future<File> _convertRawToOgg(
    sdk.RecordingFile file,
    String rawPath,
    String oggPath,
  ) async {
    final raw = await File(rawPath).readAsBytes();
    final packets = <Uint8List>[];
    if (vendorId == HardwareVendor.neview) {
      final packetSize = file.packetSizeBytes ??
          (file.format.channels == 2 ? 80 : 40);
      if (packetSize <= 0 || raw.length % packetSize != 0) {
        throw HardwareException(
          HardwareErrorCode.integrityMismatch,
          'NewView 快传原始流长度 ${raw.length} 不是包长 $packetSize 的整数倍',
        );
      }
      for (var offset = 0; offset < raw.length; offset += packetSize) {
        packets.add(Uint8List.sublistView(raw, offset, offset + packetSize));
      }
    } else {
      packets.addAll(XyrixOpusMuxer.unpackChunks(raw));
      if (XyrixOpusMuxer.skippedBytes != 0 || packets.isEmpty) {
        throw HardwareException(
          HardwareErrorCode.integrityMismatch,
          'Xyrix 快传容器无法完整切包（跳过 ${XyrixOpusMuxer.skippedBytes} B）',
        );
      }
    }

    final part = File('$oggPath.part');
    if (await part.exists()) await part.delete();
    final output = part.openWrite();
    final muxer = XyrixOpusMuxer(
      onPage: output.add,
      channels: file.format.channels,
      inputSampleRateHz: 48000,
      samplesPerPacket: _samplesPerPacket(file.format.frameDurationMs),
    );
    try {
      muxer.start();
      for (final packet in packets) {
        muxer.writePacket(packet);
      }
      muxer.finish();
      await output.flush();
      await output.close();
      final destination = File(oggPath);
      if (await destination.exists()) await destination.delete();
      return await part.rename(oggPath);
    } catch (_) {
      await output.close().catchError((_) {});
      if (await part.exists()) await part.delete();
      rethrow;
    }
  }

  static int _samplesPerPacket(int frameDurationMs) {
    final duration = frameDurationMs > 0 ? frameDurationMs : 20;
    return duration * 48;
  }

  TransferIntegrity _integrity(
    sdk.RecordingFile? file,
    sdk.TransferEvent? event,
    int actualBytes,
  ) {
    if (event?.checksumVerified == false) return TransferIntegrity.sizeMismatch;
    if (file == null || file.sizeBytes <= 0) return TransferIntegrity.unverified;
    if (actualBytes <= 0) return TransferIntegrity.sizeMismatch;
    return actualBytes == file.sizeBytes
        ? TransferIntegrity.verified
        : TransferIntegrity.sizeMismatch;
  }

  ImportedRecording _imported(
    String path,
    RecordingFile appFile,
    sdk.RecordingFile sdkFile,
    TransferIntegrity integrity,
    int actualBytes,
  ) =>
      ImportedRecording(
        filePath: path,
        recordStartTime: sdkFile.createdAt,
        durationMs: sdkFile.duration.inMilliseconds,
        fileSn: appFile.sn,
        deviceFileName: sdkFile.name,
        scene: _scene,
        integrity: integrity,
        expectedBytes: sdkFile.sizeBytes.toInt(),
        actualBytes: actualBytes,
      );

  ImportedRecording _rejected(
    RecordingFile appFile,
    sdk.RecordingFile sdkFile,
    TransferIntegrity integrity,
    sdk.TransferEvent? event,
  ) =>
      ImportedRecording(
        filePath: '',
        recordStartTime: sdkFile.createdAt,
        durationMs: sdkFile.duration.inMilliseconds,
        fileSn: appFile.sn,
        deviceFileName: sdkFile.name,
        scene: _scene,
        integrity: TransferIntegrity.sizeMismatch,
        expectedBytes: sdkFile.sizeBytes.toInt(),
        actualBytes: event?.transferredBytes ?? 0,
      );

  T _requireCapability<T extends sdk.DeviceCapability>() {
    final session = _session;
    if (session == null) {
      throw HardwareException(HardwareErrorCode.connectionLost, '设备未连接');
    }
    try {
      return session.requireCapability<T>();
    } on sdk.LynseException catch (error) {
      throw HardwareException(_mapError(error.code), error.message);
    }
  }

  Future<T> _sdkCall<T>(Future<T> Function() call, String operation) async {
    try {
      return await call();
    } on sdk.LynseException catch (error) {
      throw HardwareException(_mapError(error.code), '${error.message} ($operation)');
    }
  }

  T? _cap<T extends sdk.DeviceCapability>(sdk.DeviceSession session) {
    try {
      return session.requireCapability<T>();
    } on sdk.LynseException {
      return null;
    }
  }

  sdk.LynseHardware? _sessionHardware(sdk.DeviceSession session) {
    try {
      return _runtime.hardware;
    } catch (_) {
      return null;
    }
  }

  static RecordState _toAppRecordState(sdk.RecordingState state) =>
      switch (state) {
        sdk.RecordingState.idle => RecordState.idle,
        sdk.RecordingState.paused => RecordState.paused,
        _ => RecordState.recording,
      };

  static HardwareErrorCode _mapError(sdk.LynseErrorCode code) => switch (code) {
        sdk.LynseErrorCode.permissionDenied => HardwareErrorCode.permissionDenied,
        sdk.LynseErrorCode.authenticationFailed => HardwareErrorCode.authFailed,
        sdk.LynseErrorCode.resourceBusy => HardwareErrorCode.resourceBusy,
        sdk.LynseErrorCode.connectionLost ||
        sdk.LynseErrorCode.timeout ||
        sdk.LynseErrorCode.networkRestoreRequired =>
          HardwareErrorCode.connectionLost,
        sdk.LynseErrorCode.transferInterrupted => HardwareErrorCode.transferInterrupted,
        sdk.LynseErrorCode.unsupportedCapability => HardwareErrorCode.unsupportedCapability,
        sdk.LynseErrorCode.checksumMismatch => HardwareErrorCode.integrityMismatch,
        sdk.LynseErrorCode.vendorFailure => HardwareErrorCode.deviceError,
        _ => HardwareErrorCode.unknown,
      };

  void _emit(HardwareEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  @override
  Future<void> dispose() async {
    await stopScan();
    await disconnect();
    await _events.close();
  }
}

class _ActiveTransfer {
  _ActiveTransfer({
    required this.appFile,
    required this.sdkFile,
    required this.useWifi,
    required this.oggPath,
    required this.partPath,
    required this.rawPath,
  });

  final RecordingFile appFile;
  final sdk.RecordingFile sdkFile;
  final bool useWifi;
  final String oggPath;
  final String partPath;
  final String rawPath;
  final Completer<_Terminal> done = Completer<_Terminal>();
  _BleFileSink? sink;
  String? transferId;
  sdk.TransferEvent? lastEvent;
  String? errorMessage;
  int rounds = 0;

  void finish(_Terminal terminal) {
    if (!done.isCompleted) done.complete(terminal);
  }

  void cancel() {
    if (!done.isCompleted) done.complete(_Terminal.cancelled);
  }
}

/// BLE 数据相的落盘。SDK 用帧的 codec 说明它收到的是什么：
/// - `opus`：设备给的是 `[8B 长度][TOC]` 段容器，边收边封成 Ogg Opus。
/// - 其它（实测 `pcm16le`）：设备已经自己写好了整个文件（WAV，首帧带 `RIFF` 头），
///   逐字节原样落盘。这里再封一次只会把设备写的头弄丢。
class _BleFileSink {
  _BleFileSink({
    required this.oggPath,
    required this.partPath,
    required this.wavPath,
  });

  final String oggPath;
  final String partPath;
  final String wavPath;

  IOSink? _output;
  XyrixOpusMuxer? _muxer;
  String? _activePart;
  bool? _raw;
  int frames = 0;
  int bytes = 0;
  bool _failed = false;

  void onFrame(sdk.AudioFrame frame) {
    if (_failed) return;
    final raw = frame.format.codec != sdk.AudioCodec.opus;
    if (_raw == null) {
      _raw = raw;
      final part = raw ? '$wavPath.part' : partPath;
      final output = File(part).openWrite();
      _activePart = part;
      _output = output;
      if (!raw) {
        final muxer = XyrixOpusMuxer(
          onPage: output.add,
          channels: frame.format.channels,
          inputSampleRateHz: 48000,
          samplesPerPacket:
              (frame.format.frameDurationMs > 0 ? frame.format.frameDurationMs : 20) * 48,
        );
        muxer.start();
        _muxer = muxer;
      }
    } else if (_raw != raw) {
      debugPrint('[LynseSDK] 同一次传输里混进了两种载荷，判为失败');
      _failed = true;
      return;
    }
    try {
      if (_raw!) {
        _output?.add(frame.payload);
      } else {
        _muxer!.writePacket(frame.payload);
      }
      frames += 1;
      bytes += frame.payload.length;
    } catch (error) {
      debugPrint('[LynseSDK] 落盘失败: $error');
      _failed = true;
    }
  }

  Future<File?> finish(bool success) async {
    final raw = _raw ?? false;
    final part = File(_activePart ?? _rawPathFor(raw));
    final muxer = _muxer;
    if (success && !raw) {
      try {
        muxer?.finish();
      } catch (error) {
        debugPrint('[LynseSDK] Ogg finish failed: $error');
        success = false;
      }
    } else if (success && raw && _failed) {
      success = false;
    }
    try {
      await _output?.flush();
      await _output?.close();
    } catch (_) {}
    if (!success || frames == 0 || !await part.exists()) {
      if (await part.exists()) await part.delete();
      return null;
    }
    final destination = File(raw ? wavPath : oggPath);
    if (await destination.exists()) await destination.delete();
    return part.rename(destination.path);
  }

  String _rawPathFor(bool raw) => raw ? '$wavPath.part' : partPath;
}

class _Paths {
  const _Paths({
    required this.ogg,
    required this.part,
    required this.raw,
    required this.wav,
  });
  final String ogg;
  final String part;
  final String raw;

  /// 设备自己写好整个文件（实测 Xyrix 会直接给 WAV）时的落盘名。
  final String wav;
}

enum _Terminal { completed, failed, cancelled }

/// 设备会话控制器：硬件抽象层的 GetX 门面。
///
/// 助手版 UI 只订阅本控制器的状态，不直接接触任何厂商 SDK。
/// 本层不弹任何 UI（snackbar/dialog），需要用户感知的结果通过
/// [sessionNotice] 交给 UI 层呈现。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dting/config/config.dart';
import 'package:dting/core/hardware/hardware_kit.dart';
import 'package:dting/utils/local_database.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

/// 面向用户的会话通知（连接结果、重连失败等），由 UI 层决定如何呈现。
class SessionNotice {
  final String title;
  final String message;
  final bool isError;

  const SessionNotice(this.title, this.message, {this.isError = false});
}

class DeviceSessionController extends GetxController {
  DeviceSessionController._();

  static DeviceSessionController get instance => Get.find<DeviceSessionController>();

  static DeviceSessionController init() {
    final c = DeviceSessionController._();
    Get.put(c, permanent: true);
    return c;
  }

  /// 最近一次成功连接的设备（json：vendorId/deviceId/name），供启动自动重连
  static const String _lastDeviceKey = 'lastHwDeviceJson';

  late final NeviewAdapter neview;
  late final XyrixAdapter xyrix;
  late final AdapterRegistry registry;

  final ResourceArbiter _arbiter = ResourceArbiter();

  final Map<String, StreamSubscription<HardwareEvent>> _subs = {};

  // ---- 可订阅状态 ----
  final activeVendor = Rxn<String>();
  final scanning = false.obs;
  final discoveredDevices = <DiscoveredDevice>[].obs;
  final connectionPhase = ConnectionPhase.disconnected.obs;
  final connectedDevice = Rxn<DiscoveredDevice>();
  final battery = Rxn<BatteryStatus>();
  final deviceInfo = Rxn<DeviceHardwareInfo>();
  final recordState = RecordState.idle.obs;
  final recordScene = RecordScene.meeting.obs;
  final deviceFiles = <RecordingFile>[].obs;

  /// 已下载到本机的设备文件名（持久化，UI 用作"已下载"标识）
  final downloadedNames = <String>[].obs;
  static const String _downloadedKey = 'downloadedDeviceFileNames';

  bool isDownloaded(String name) => downloadedNames.contains(name);

  void markDownloaded(String name) {
    if (!downloadedNames.contains(name)) {
      downloadedNames.add(name);
      LocalDataBase()
          .basicBox!
          .put(_downloadedKey, downloadedNames.toList());
    }
  }

  void _loadDownloadedNames() {
    final raw = LocalDataBase().basicBox!.get(_downloadedKey);
    if (raw is List) {
      downloadedNames.assignAll(raw.map((e) => e.toString()));
    }
  }
  final transferProgress = Rxn<TransferProgress>();
  final wifiStatus = Rxn<WifiTransferStatus>();
  final firmwareEvent = Rxn<FirmwareEvent>();
  final lastImported = Rxn<ImportedRecording>();
  final lastError = Rxn<String>();
  final sessionNotice = Rxn<SessionNotice>();

  BleDeviceAdapter? get active {
    final vendor = activeVendor.value;
    return vendor == null ? null : registry.byVendor(vendor);
  }

  /// App 启动时调用一次（NvEasyPlugin.init 之后）
  void bootstrap() {
    _loadDownloadedNames();
    neview = NeviewAdapter()..attach();
    xyrix = XyrixAdapter();
    registry = AdapterRegistry()
      ..register(neview)
      ..register(xyrix);
    for (final adapter in registry.all) {
      _subs[adapter.vendorId] = adapter.events.listen(_onEvent);
    }
  }

  void _onEvent(HardwareEvent event) {
    switch (event) {
      case DeviceDiscoveredEvent(:final device):
        final exists =
            discoveredDevices.any((d) => d.deviceId == device.deviceId);
        if (!exists) {
          discoveredDevices.add(device);
          discoveredDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
        }
        break;
      case ScanStateEvent(scanning: final isScanning):
        scanning.value = isScanning;
        break;
      case ConnectionStateEvent(:final phase):
        connectionPhase.value = phase;
        if (phase == ConnectionPhase.disconnected) {
          connectedDevice.value = null;
          recordState.value = RecordState.idle;
          _arbiter.release(ExclusiveResource.recording);
          _arbiter.release(ExclusiveResource.fileTransfer);
          _arbiter.release(ExclusiveResource.firmwareUpgrade);
        }
        break;
      case BatteryEvent(battery: final status):
        battery.value = status;
        break;
      case DeviceInfoEvent(:final info):
        final old = deviceInfo.value;
        deviceInfo.value = DeviceHardwareInfo(
          firmwareVersion: info.firmwareVersion ?? old?.firmwareVersion,
          hardwareVersion: info.hardwareVersion ?? old?.hardwareVersion,
          serialNumber: info.serialNumber ?? old?.serialNumber,
          storageFreeKb: info.storageFreeKb ?? old?.storageFreeKb,
          storageTotalKb: info.storageTotalKb ?? old?.storageTotalKb,
        );
        break;
      case RecordSceneEvent(:final scene):
        recordScene.value = scene;
        break;
      case RecordStateEvent(:final state, :final scene):
        recordState.value = state;
        if (scene != null) {
          recordScene.value = scene;
        }
        break;
      case FileListEvent(:final files):
        deviceFiles.assignAll(files);
        _selfTestLog('[链路] 控制器收到 FileListEvent: ${files.length} 个, '
            'assignAll 后 deviceFiles.length=${deviceFiles.length}');
        break;
      case TransferProgressEvent(:final progress):
        transferProgress.value = progress;
        break;
      case FileImportedEvent(:final recording):
        lastImported.value = recording;
        // 下载完成的设备文件标记为已下载（BLE 下载路径文件名形如
        // xyrix_dl_<设备文件名>）
        final name = recording.filePath.split('/').last;
        if (name.startsWith('xyrix_dl_')) {
          markDownloaded(name.substring('xyrix_dl_'.length));
        }
        break;
      case FirmwareEvent e:
        firmwareEvent.value = e;
        break;
      case BluetoothOffEvent():
        connectionPhase.value = ConnectionPhase.disconnected;
        connectedDevice.value = null;
        break;
      case HardwareErrorEvent(:final code, :final message):
        lastError.value = '$code $message';
        break;
      case WifiStatusEvent(:final status):
        wifiStatus.value = status;
        break;
    }
  }

  /// 自测链路日志：写入 Documents/xyrix_selftest_report.txt（与适配器共用）
  static Future<void> _selfTestLog(String line) async {
    if (!Config.selfTestXyrix) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/xyrix_selftest_report.txt')
          .writeAsString('[UI链路] $line\n', mode: FileMode.append);
    } catch (_) {}
  }

  // ------------------------------------------------------------------
  // 扫描 / 连接
  // ------------------------------------------------------------------

  Future<void> startScan() async {
    final adapter = active;
    if (adapter == null) {
      lastError.value = '未选择设备厂商';
      return;
    }
    discoveredDevices.clear();
    scanning.value = true;
    try {
      await adapter.startScan();
    } on HardwareException catch (e) {
      lastError.value = e.message;
      scanning.value = false;
    }
  }

  Future<void> stopScan() async {
    await active?.stopScan();
    scanning.value = false;
  }

  Future<void> connect(DiscoveredDevice device, {String? authKey}) async {
    // 厂商由设备广播决定，切换 active adapter
    activeVendor.value = device.vendorId;
    final key = authKey ??
        LocalDataBase().basicBox!.get('neview_appkey')?.toString();
    await active?.connect(device, authKey: key);
    connectedDevice.value = device;
    await queryDeviceInfo();
    // 连接成功自动拉取设备文件列表，列表卡片即刻可用
    await refreshFiles();
    // 记住最近连接的设备：下次进外壳页自动重连（不经扫描，按系统设备
    // 标识直连，扫描列表刷不出来时也能连上）
    LocalDataBase().basicBox!.put(
      _lastDeviceKey,
      jsonEncode({
        'vendorId': device.vendorId,
        'deviceId': device.deviceId,
        'name': device.name,
      }),
    );
  }

  /// 自动重连上次连接的设备。iOS 对连过的外设有系统级缓存，
  /// 直连不需要设备正在广播；设备休眠/没电时会以超时失败告终。
  Future<void> autoReconnect() async {
    if (connectionPhase.value.isUsable && connectedDevice.value != null) {
      return;
    }
    final raw = LocalDataBase().basicBox!.get(_lastDeviceKey)?.toString();
    if (raw == null || raw.isEmpty) return;
    Map<String, dynamic> map;
    try {
      map = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final vendorId = map['vendorId'] as String?;
    final deviceId = map['deviceId'] as String?;
    if (vendorId == null || deviceId == null) return;
    if (registry.byVendor(vendorId) == null) return;
    final device = DiscoveredDevice(
      vendorId: vendorId,
      deviceId: deviceId,
      name: (map['name'] as String?) ?? '上次设备',
      rssi: 0,
    );
    try {
      await connect(device);
      sessionNotice.value = SessionNotice('已自动连接', device.name);
    } catch (e) {
      sessionNotice.value = SessionNotice(
        '自动重连失败',
        '请确认 ${device.name} 已开机、有电并靠近手机，再手动扫描连接',
        isError: true,
      );
    }
  }

  Future<void> disconnect() async {
    await active?.disconnect();
  }

  Future<void> queryDeviceInfo() async {
    try {
      await active?.queryDeviceInfo();
    } on HardwareException catch (e) {
      lastError.value = e.message;
    }
  }

  /// 连接后的自动重连目标（沿用基座本地缓存键）
  String? get lastConnectedDeviceId =>
      LocalDataBase().basicBox!.get('didConnect')?.toString();

  // ------------------------------------------------------------------
  // 录音控制
  // ------------------------------------------------------------------

  Future<void> startRecording(RecordScene mode) async {
    try {
      _arbiter.acquire(ExclusiveResource.recording);
    } on HardwareException catch (e) {
      lastError.value = e.message;
      return;
    }
    recordScene.value = mode;
    try {
      await active?.startRecord(mode);
    } on HardwareException catch (e) {
      _arbiter.release(ExclusiveResource.recording);
      lastError.value = e.message;
    }
  }

  Future<void> pauseRecording() async {
    try {
      await active?.pauseRecord();
    } on HardwareException catch (e) {
      lastError.value = e.message;
    }
  }

  Future<void> resumeRecording() async {
    try {
      await active?.resumeRecord();
    } on HardwareException catch (e) {
      lastError.value = e.message;
    }
  }

  Future<void> stopRecording() async {
    try {
      await active?.stopRecord();
    } on HardwareException catch (e) {
      lastError.value = e.message;
    } finally {
      _arbiter.release(ExclusiveResource.recording);
    }
  }

  // ------------------------------------------------------------------
  // 文件 / OTA
  // ------------------------------------------------------------------

  Future<void> refreshFiles() async {
    try {
      _arbiter.acquire(ExclusiveResource.fileTransfer);
      await active?.listFiles();
    } on HardwareException catch (e) {
      lastError.value = e.message;
    } finally {
      _arbiter.release(ExclusiveResource.fileTransfer);
    }
  }

  Future<void> downloadDeviceFile(RecordingFile file,
      {bool useWifi = true}) async {
    final adapter = active;
    if (adapter == null) return;
    try {
      _arbiter.acquire(ExclusiveResource.fileTransfer);
      final transport = useWifi &&
              adapter.capabilities.supports(HardwareCapability.wifiTransfer)
          ? TransferTransport.wifi
          : TransferTransport.ble;
      await adapter.downloadFile(file, transport: transport);
    } on HardwareException catch (e) {
      lastError.value = e.message;
    } finally {
      _arbiter.release(ExclusiveResource.fileTransfer);
    }
  }

  Future<void> upgradeFirmware(String filePath, String newVersion) async {
    try {
      _arbiter.acquire(ExclusiveResource.firmwareUpgrade);
      await active?.upgradeFirmware(filePath: filePath, newVersion: newVersion);
    } on HardwareException catch (e) {
      lastError.value = e.message;
    } finally {
      _arbiter.release(ExclusiveResource.firmwareUpgrade);
    }
  }

  /// 厂商能力判断（UI 显隐用）
  bool supports(HardwareCapability c) =>
      active?.capabilities.supports(c) ?? false;

  @override
  void onClose() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    registry.dispose();
    super.onClose();
  }
}

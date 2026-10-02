/// 厂商设备适配器抽象 + 互斥仲裁 + 注册表。
library;

import 'dart:async';

import 'hardware_event.dart';
import 'models.dart';

/// 厂商设备适配器：把厂商 SDK 的扫描/连接/录音/文件/OTA
/// 翻译成统一的事件流与异步接口。UI 与业务只依赖本抽象。
abstract class BleDeviceAdapter {
  /// 厂商标识（[HardwareVendor]）
  String get vendorId;

  /// 展示名（设备添加页选择厂商时用）
  String get vendorDisplayName;

  CapabilityManifest get capabilities;

  /// 统一事件流（broadcast）
  Stream<HardwareEvent> get events;

  // ---- 扫描 / 连接 ----

  Future<void> startScan({Duration timeout = const Duration(seconds: 15)});

  Future<void> stopScan();

  /// 连接设备。
  /// [authKey] 为厂商鉴权凭证（Neview 的 16 位 AppKey；Xyrix 无鉴权可传 null）。
  Future<void> connect(DiscoveredDevice device, {String? authKey});

  Future<void> disconnect();

  /// 主动查询设备信息（电量/版本/存储），结果经 [events] 推送。
  Future<void> queryDeviceInfo();

  // ---- 录音控制 ----

  Future<void> startRecord(RecordScene mode);

  Future<void> pauseRecord();

  Future<void> resumeRecord();

  Future<void> stopRecord();

  /// 录音中添加标记（对应桌面端 recMark / 书签）
  Future<void> addMark();

  // ---- 设备内文件 ----

  /// 获取文件列表，完成后经 [FileListEvent] 推送。
  Future<List<RecordingFile>> listFiles();

  /// 下载设备内录音文件，导入完成后经 [FileImportedEvent] 推送。
  Future<void> downloadFile(
    RecordingFile file, {
    TransferTransport transport = TransferTransport.wifi,
    bool autoDelete = false,
  });

  Future<void> cancelDownload();

  Future<void> deleteFile(RecordingFile file);

  // ---- OTA ----

  Future<void> upgradeFirmware({
    required String filePath,
    required String newVersion,
  });

  Future<void> dispose();
}

/// 互斥资源仲裁：录音、文件传输、OTA 互斥（Neview 硬约束，全厂商统一遵守）。
class ResourceArbiter {
  ExclusiveResource? _held;

  /// 占用资源；已被占用时抛 [HardwareException]（resourceBusy）。
  void acquire(ExclusiveResource resource) {
    final held = _held;
    if (held != null && held != resource) {
      throw HardwareException(
        HardwareErrorCode.resourceBusy,
        '资源被占用: $held，请求: $resource',
      );
    }
    _held = resource;
  }

  void release(ExclusiveResource resource) {
    if (_held == resource) {
      _held = null;
    }
  }

  ExclusiveResource? get held => _held;
}

enum ExclusiveResource { recording, fileTransfer, firmwareUpgrade }

/// 适配器注册表：按厂商标识注册/查找 adapter。
class AdapterRegistry {
  final Map<String, BleDeviceAdapter> _adapters = {};

  void register(BleDeviceAdapter adapter) {
    _adapters[adapter.vendorId] = adapter;
  }

  BleDeviceAdapter? byVendor(String vendorId) => _adapters[vendorId];

  List<BleDeviceAdapter> get all => _adapters.values.toList(growable: false);

  /// 释放全部适配器资源
  Future<void> dispose() async {
    for (final adapter in _adapters.values) {
      await adapter.dispose();
    }
    _adapters.clear();
  }
}

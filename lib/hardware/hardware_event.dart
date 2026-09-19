/// 硬件统一事件流。
///
/// 各厂商 adapter 把自家 SDK 的回调翻译成这里的事件；
/// 业务/UI 侧只订阅 `BleDeviceAdapter.events` 一种流。
library;

import 'models.dart';

sealed class HardwareEvent {
  const HardwareEvent();
}

/// 扫描发现设备
class DeviceDiscoveredEvent extends HardwareEvent {
  final DiscoveredDevice device;

  const DeviceDiscoveredEvent(this.device);
}

/// 扫描状态变化
class ScanStateEvent extends HardwareEvent {
  final bool scanning;

  const ScanStateEvent(this.scanning);
}

/// 连接状态变化
class ConnectionStateEvent extends HardwareEvent {
  final String deviceId;
  final ConnectionPhase phase;

  /// phase == error 时的描述
  final String? errorMessage;

  const ConnectionStateEvent(this.deviceId, this.phase, {this.errorMessage});
}

/// 电量更新
class BatteryEvent extends HardwareEvent {
  final BatteryStatus battery;

  const BatteryEvent(this.battery);
}

/// 设备信息（版本 / SN / 存储）
class DeviceInfoEvent extends HardwareEvent {
  final DeviceHardwareInfo info;

  const DeviceInfoEvent(this.info);
}

/// 录音场景更新（会议 / 通话，对应 Neview didUpdateMeetingType）
class RecordSceneEvent extends HardwareEvent {
  final RecordScene scene;

  const RecordSceneEvent(this.scene);
}

/// 录音状态更新（设备侧发起，含 App 主动控制后的回执）
class RecordStateEvent extends HardwareEvent {
  final RecordState state;
  final RecordScene? scene;

  /// 录音生成时的文件名（若有）
  final String? fileName;

  const RecordStateEvent(this.state, {this.scene, this.fileName});
}

/// 设备文件列表到达
class FileListEvent extends HardwareEvent {
  final List<RecordingFile> files;

  const FileListEvent(this.files);
}

/// 文件传输进度
class TransferProgressEvent extends HardwareEvent {
  final TransferProgress progress;

  /// 正在传输的设备内文件序号（批量下载时可能为 null）
  final int? fileSn;

  const TransferProgressEvent(this.progress, {this.fileSn});
}

/// 一条录音导入完成（BLE 下载 / WiFi 快传 / 录音停止落盘）
class FileImportedEvent extends HardwareEvent {
  final ImportedRecording recording;

  const FileImportedEvent(this.recording);
}

/// WiFi 快传链路状态
class WifiStatusEvent extends HardwareEvent {
  final WifiTransferStatus status;

  const WifiStatusEvent(this.status);
}

/// OTA 进度/结果
class FirmwareEvent extends HardwareEvent {
  final FirmwareState state;
  final int progressPercent;

  /// 已升级字节数（可选）
  final int? upgradedBytes;

  final String? error;

  const FirmwareEvent(
    this.state, {
    this.progressPercent = 0,
    this.upgradedBytes,
    this.error,
  });
}

/// 手机蓝牙被关闭
class BluetoothOffEvent extends HardwareEvent {
  const BluetoothOffEvent();
}

/// 错误
class HardwareErrorEvent extends HardwareEvent {
  final HardwareErrorCode code;
  final String message;

  const HardwareErrorEvent(this.code, [this.message = '']);
}

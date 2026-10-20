/// 硬件抽象层统一数据模型。
///
/// 该层是厂商无关的领域模型：UI 与业务代码只依赖这里的类型，
/// 各厂商差异由 [BleDeviceAdapter] 实现负责翻译。
library;

/// 厂商标识（与 AdapterRegistry 注册的 adapter 一一对应）
abstract final class HardwareVendor {
  static const String neview = 'neview';
  static const String xyrix = 'xyrix';
}

/// 录音场景（对齐 lynse-desktop RecordingMode）
enum RecordScene { meeting, call, media, unknown }

/// 录音控制状态
enum RecordState { idle, recording, paused }

/// 连接阶段
enum ConnectionPhase { disconnected, connecting, connected, ready }

/// [ConnectionPhase] 的 UI 判断辅助。
///
/// `connected` 只是过渡态（Neview 终态为 connected；Xyrix 服务发现完成后
/// 会继续推进到 ready），UI 显示「已连接」/放行操作应使用 [isUsable]。
extension ConnectionPhaseX on ConnectionPhase {
  bool get isUsable =>
      this == ConnectionPhase.connected || this == ConnectionPhase.ready;
}

/// 文件传输通道
enum TransferTransport { ble, wifi }

/// 文件传输状态
enum TransferState { idle, transferring, completed, failed, cancelled }

/// 传输完整性判定：字节数与权威期望大小（设备 0x2D 应答确认的大小）是否吻合。
///
/// 只有 [verified] 的产物才可入库/标记已下载——`completed` 只代表链路结束，
/// 不代表内容完好。
enum TransferIntegrity {
  /// 落盘字节 == 期望字节，且传输期间无过收
  verified,

  /// 落盘字节与期望不符（少收或多收），文件内容不可信
  sizeMismatch,

  /// 期望大小未知（设备未确认且列表未上报），无法校验
  unverified,
}

/// 一次传输的终止意图：决定断点文件是否保留。
enum TransferStopIntent {
  /// 仍在进行中
  none,

  /// 用户主动取消：断点作废，不留半成品
  userCancelled,

  /// 链路意外中断（掉线/断流/进程被杀）：保留断点，下次自动续传
  interrupted,
}

/// OTA / 固件升级状态（对齐 Neview 插件 0=STARTED 1=PROGRESS 2=SUCCESS 3=FAILED）
enum FirmwareState { idle, started, progress, success, failed }

/// WiFi 快传链路状态（对齐 Neview 插件 0-5）
enum WifiTransferStatus { opening, opened, connecting, connected, stopping, stopped }

/// 统一错误码（借鉴 lynse-hardware-sdk 的标准错误面，仅做本层约定）
enum HardwareErrorCode {
  /// 厂商鉴权失败（如 Neview 16 位 AppKey 错误）
  authFailed,

  /// 资源冲突：录音 / 文件传输 / OTA 互斥
  resourceBusy,

  connectionLost,
  transferInterrupted,
  unsupportedCapability,

  /// 传输结束但字节数与设备确认大小不符：内容不可信，不得入库
  integrityMismatch,

  /// 设备返回失败
  deviceError,

  unknown,
}

/// 硬件层业务异常
class HardwareException implements Exception {
  final HardwareErrorCode code;
  final String message;

  HardwareException(this.code, [this.message = '']);

  @override
  String toString() => 'HardwareException($code, $message)';
}

/// 能力项：UI 据此决定功能显隐，不按厂商标识分支
enum HardwareCapability {
  /// 录音中添加标记
  addMark,

  /// 暂停/恢复录音
  pauseResume,

  /// 实时音频流（波形展示）
  liveAudio,

  /// WiFi 快传（设备热点 / TCP）
  wifiTransfer,

  /// 固件 OTA 升级
  firmwareUpgrade,

  /// 删除设备内录音文件
  deleteFile,
}

/// 能力清单
class CapabilityManifest {
  final Set<HardwareCapability> supported;

  const CapabilityManifest(this.supported);

  bool supports(HardwareCapability c) => supported.contains(c);
}

/// 扫描发现的设备
class DiscoveredDevice {
  /// 厂商标识（neview / xyrix）
  final String vendorId;

  /// 平台设备标识：iOS 为 peripheral UUID，Android 为 MAC
  final String deviceId;

  final String name;
  final int rssi;

  /// 原始广播厂商数据（用于厂商匹配与 SN 解析）
  final List<int> manufacturerData;

  const DiscoveredDevice({
    required this.vendorId,
    required this.deviceId,
    required this.name,
    required this.rssi,
    this.manufacturerData = const [],
  });

  DiscoveredDevice copyWith({String? name, int? rssi}) => DiscoveredDevice(
        vendorId: vendorId,
        deviceId: deviceId,
        name: name ?? this.name,
        rssi: rssi ?? this.rssi,
        manufacturerData: manufacturerData,
      );
}

/// 电量状态
class BatteryStatus {
  /// 0-100；耳机类设备为整体电量（由 adapter 归一）
  final int levelPercent;
  final bool isCharging;

  const BatteryStatus({required this.levelPercent, this.isCharging = false});
}

/// 设备硬件信息
class DeviceHardwareInfo {
  final String? firmwareVersion;
  final String? hardwareVersion;
  final String? serialNumber;

  /// 存储（KB），未知为 null
  final int? storageFreeKb;
  final int? storageTotalKb;

  const DeviceHardwareInfo({
    this.firmwareVersion,
    this.hardwareVersion,
    this.serialNumber,
    this.storageFreeKb,
    this.storageTotalKb,
  });
}

/// 设备内的录音文件
class RecordingFile {
  /// 文件序号（厂商内部标识，下载/删除用）
  final int sn;

  final String name;
  final int sizeBytes;
  final RecordScene scene;
  final DateTime? startTime;
  final DateTime? endTime;

  const RecordingFile({
    required this.sn,
    required this.name,
    this.sizeBytes = 0,
    this.scene = RecordScene.unknown,
    this.startTime,
    this.endTime,
  });
}

/// 传输进度快照（包进度对齐 Neview 插件；字节进度用于 Xyrix/WiFi）
class TransferProgress {
  final TransferState state;

  /// 当前文件序号（多文件批量下载时的第 N 个）
  final int currentFileIndex;

  final int currentPacket;
  final int totalPacket;
  final int speedKbps;

  /// 已接收 / 总字节（可选，包粒度不足时使用）
  final int? receivedBytes;
  final int? totalBytes;

  /// 终止时的完整性判定（进行中为 null）
  final TransferIntegrity? integrity;

  const TransferProgress({
    this.state = TransferState.idle,
    this.currentFileIndex = 0,
    this.currentPacket = 0,
    this.totalPacket = 1,
    this.speedKbps = 0,
    this.receivedBytes,
    this.totalBytes,
    this.integrity,
  });

  /// 0.0 - 1.0
  double get fraction {
    if (totalBytes != null && totalBytes! > 0) {
      return (receivedBytes ?? 0) / totalBytes!;
    }
    if (totalPacket > 0) {
      return currentPacket / totalPacket;
    }
    return 0;
  }
}

/// 一条导入完成的录音（对应插件 didReceiveRecordMP3FilePath / wifiDidGetFile）
class ImportedRecording {
  /// 本地已转换的音频文件路径（mp3）
  final String filePath;

  final DateTime? recordStartTime;
  final int? durationMs;

  /// 设备内文件序号（BLE 下载/WiFi 快传时携带）
  final int? fileSn;

  /// 设备侧的原始文件名；上层据此标记「已下载」，不再靠剥本地路径前缀
  final String? deviceFileName;

  final RecordScene scene;

  /// 完整性判定结果与参与判定的两个字节数（期望未知时为 0）
  final TransferIntegrity integrity;
  final int expectedBytes;
  final int actualBytes;

  const ImportedRecording({
    required this.filePath,
    this.recordStartTime,
    this.durationMs,
    this.fileSn,
    this.deviceFileName,
    this.scene = RecordScene.unknown,
    this.integrity = TransferIntegrity.unverified,
    this.expectedBytes = 0,
    this.actualBytes = 0,
  });

  /// 明确校验不通过（字节数与期望不符）：任何上层都不得把它当录音使用。
  /// [TransferIntegrity.unverified] 不在此列——那代表厂商 SDK 自行负责完整性
  /// （Neview 路径），不是"我们发现它坏了"。
  bool get isRejected => integrity == TransferIntegrity.sizeMismatch;
}

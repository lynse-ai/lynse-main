/// Xyrix BLE 协议命令码表（来源：XyrixSDK-2/ble_sdk/docs/API_Reference.md §8）。
///
/// 帧格式：`FF 55 AA [长度 1B] [命令码 1B] [数据 N 字节]`，长度 = 1 + N（不含帧头）。
library;

abstract final class XyrixCommands {
  // ---- 设备信息 ----
  /// 查询电池电量；响应 2 字节 [电量, 充电状态]
  static const int queryBattery = 0x01;

  /// 修改蓝牙名称（≤6 字节）
  static const int setBtName = 0x02;

  /// 重启蓝牙模块
  static const int rebootBt = 0x03;

  /// 查询文件详情（时长+大小+路径）；附加：文件名
  static const int fileInfo = 0x04;

  /// 查询文件列表；附加：路径（如 "0:/ .wav"）
  static const int fileList = 0x05;

  /// 删除文件；附加：完整路径（如 "0:/record_1.wav"）
  static const int deleteFile = 0x12;

  /// 同步设备时间；附加：4 字节大端 Unix 时间戳
  static const int syncTime = 0x13;

  /// 查询固件版本号
  static const int queryVersion = 0x17;

  /// 获取蓝牙设备号（响应即 SN）
  static const int queryDeviceId = 0xFF;

  /// 隐藏热点（名称+密码）
  static const int hiddenHotspot = 0x11;

  /// 开启热点
  static const int openHotspot = 0x20;

  /// 开启热点并打开 TCP 服务
  static const int openHotspotTcp = 0x21;

  /// 关闭 Wi-Fi
  static const int closeWifi = 0x23;

  /// 查询录音卡状态
  static const int recordCardStatus = 0x1A;

  // ---- 录音控制 ----
  static const int recordStart = 0x1B;
  static const int recordPause = 0x1C;
  static const int recordSave = 0x1D;
  static const int recordDiscard = 0x1E;
  static const int recordResume = 0x1F;

  /// 边录音边蓝牙传数据
  static const int recordWithTransfer = 0x24;

  // ---- 录音转写 ----
  static const int rtStart = 0x32;
  static const int rtPause = 0x33;
  static const int rtStopSave = 0x34;
  static const int rtResume = 0x35;

  // ---- 文件传输 ----
  /// 准备传输（杰理芯片）：绝对路径 + 大小
  static const int transferPrepareJl = 0x07;

  /// 启动传输（杰理芯片）
  static const int transferStartJl = 0x08;

  /// 准备传输（Telink 芯片）：仅路径
  static const int transferPrepareTelink = 0x43;

  /// 启动传输（Telink 芯片）完整帧 FF 55 AA 02 00 08 00
  static const int transferStartTelink = 0x00;

  /// WiFi 传输触发（断点续传）：路径 hex + 4 字节大端断点
  static const int wifiTransferResume = 0x46;

  /// 停止 WiFi 传输
  static const int wifiTransferStop = 0x47;

  /// 停止 BLE 传输
  static const int bleTransferStop = 0x48;

  /// 查询存储空间
  static const int queryStorage = 0x2E;

  // ---- OPUS 录音 ----
  static const int opusStart = 0x50;
  static const int opusPause = 0x51;
  static const int opusResume = 0x52;
  static const int opusEnd = 0x53;
  static const int opusDiscard = 0x55;
}

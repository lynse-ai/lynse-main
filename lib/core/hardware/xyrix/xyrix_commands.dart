/// Xyrix BLE 协议命令码表（来源：XyrixSDK-2 文档 §8 + 真机联调实测）。
///
/// 帧格式：`FF 55 AA [长度 1B] [命令码 1B] [数据 N 字节]`，长度 = N（数据字节数）。
///
/// 每条命令后面的注释是**本版固件（v2.0.13，SN 2606260101400084）实测结果**
/// （2026-10-05 用 lib/core/hardware/xyrix/xyrix_probe.dart 逐条打真机取得）：
/// - 「无回执」= 设备收到并执行，但不回任何帧（录音类命令全属此类）
/// - 「无响应」= 本版固件根本不处理该命令
library;

abstract final class XyrixCommands {
  // ---- 设备信息 ----
  /// 查询电池电量；响应 2 字节 [电量, 充电状态]（实测 `45 00` = 69%、未充电）
  static const int queryBattery = 0x01;

  /// 命令完成 ACK（联调实测：每条响应帧后紧跟 `FF 55 AA 00 2F`）
  static const int commandAck = 0x2F;

  /// 修改蓝牙名称（≤6 字节）——未实测（改名有副作用，探测台仅在 L5 复原原名）
  static const int setBtName = 0x02;

  /// 重启蓝牙模块——未实测（会断 GATT，探测台放在最后一步）
  static const int rebootBt = 0x03;

  /// 查询文件详情（时长+大小+路径）；附加：文件名。实测**无响应**，
  /// 单文件信息只能从 0x05 列表行取
  static const int fileInfo = 0x04;

  /// 查询文件列表；附加：路径（如 "0:/ .wav"）。实测有效：明文行 + `2F` 结束
  static const int fileList = 0x05;

  /// 删除文件；附加：完整路径（如 "0:/record_1.wav"）——未在真机验证（破坏性）
  static const int deleteFile = 0x12;

  /// 同步设备时间；附加：4 字节大端 Unix 时间戳。实测回 `2F` ACK
  static const int syncTime = 0x13;

  /// 查询固件版本号。实测响应
  /// `2025-01-01-12:00:00 v2.0.13`（设备时钟未同步时就是这个假默认值）
  static const int queryVersion = 0x17;

  /// 获取蓝牙设备号（响应即 SN）。实测本版固件**无响应**，SN 取广播
  /// manufacturerData（companyId 0xABCD 的 ASCII 载荷）
  static const int queryDeviceId = 0xFF;

  /// 隐藏热点（名称+密码）。实测**无响应**
  static const int hiddenHotspot = 0x11;

  /// 开启热点。实测**无响应**（0x21 才有回执）
  static const int openHotspot = 0x20;

  /// 开启热点并打开 TCP 服务。实测响应 `FF 55 AA 01 21 01` + ACK——
  /// **只有一个状态字节，不含 SSID/密码**，所以「蓝牙下发热点凭证」这条
  /// 设计路径在本版固件上不成立
  static const int openHotspotTcp = 0x21;

  /// 关闭 Wi-Fi。实测响应 `FF 55 AA 01 23 01` + ACK
  static const int closeWifi = 0x23;

  /// 查询录音卡状态。实测响应 4 字节 `00 00 00 00`，字段语义未确认
  static const int recordCardStatus = 0x1A;

  // ---- 录音控制 ----
  // 实测：0x1B/0x1C/0x1F/0x50/0x52/0x53/0x32-0x35 一律**无回执**，
  // GATT 写入成功即生效（0x1D 例外，回 2F ACK）。判定录音状态只能靠
  // 0x54 推流是否出现、以及 0x05 列表里是否多出新文件。
  static const int recordStart = 0x1B;
  static const int recordPause = 0x1C;
  static const int recordSave = 0x1D;
  static const int recordDiscard = 0x1E;
  static const int recordResume = 0x1F;

  /// 边录音边蓝牙传数据。本版固件实测无推流也不保存（2026-09-30 自测：
  /// 15s 0 包，同期 0x1B 15s 648 包 / 55KB），弃用
  static const int recordWithTransfer = 0x24;

  // ---- 录音转写 ----
  static const int rtStart = 0x32;
  static const int rtPause = 0x33;
  static const int rtStopSave = 0x34;
  static const int rtResume = 0x35;

  // ---- 同声传译（SDK 文档 §8.8，此前命令表里完全没有）----
  static const int siStart = 0x36;
  static const int siPause = 0x37;
  static const int siResume = 0x38;
  static const int siStopSave = 0x39;

  // ---- 会话翻译（SDK 文档 §8.9）----
  static const int conversationStart = 0x40;
  static const int conversationStop = 0x41;

  // ---- 交互与模式（SDK 文档 §8.12）----
  /// 长按按钮响应：`1`=确认，`0`=取消。
  /// 曾经怀疑设备在等这条才肯继续（0x07/0x08 之后零字节下发）——已排除，
  /// 真正原因是启动帧写法，见 [transferStartTelink]
  static const int buttonConfirm = 0x30;

  /// 退出 APP 命令
  static const int exitApp = 0x31;

  /// R4_2 翻译/录音模式切换：`1`=翻译，`0`=录音
  static const int switchMode = 0x60;

  // ---- 文件传输 ----
  /// 传输准备就绪应答（0x2D）：App 发 0x07 后设备回
  /// `FF 55 AA 04 2D [4B 文件大小 BE]` + ACK。收到它之后才能发启动帧，
  /// 否则设备不推数据。文档未列出此命令码
  static const int transferReady = 0x2D;

  /// 准备传输（杰理芯片）：绝对路径 + 4 字节文件大小（大端）。
  /// 实测本卡认这条：0x43（只带路径）换不来 0x2D 应答
  static const int transferPrepareJl = 0x07;

  /// 启动传输（杰理芯片）。
  ///
  /// ⚠️ 2026-10-06 真机实证：**本卡不吃裸 0x08**。穷举过 10 种 0x07 载荷
  /// （裸路径 / +sizeBE / +sizeLE / +时长…）× 6 种启动写法（0x08 空 /
  /// 0x08+path / 0x08+[01] / 0x08+sizeBE / 不发启动 / 0x00[08 00]），
  /// 只有 `transferStartTelink` 那一格收到数据，其余全为 0 字节。
  /// 所以名字里的「杰理」只是文档的分组说法，不代表本卡可用；保留常量
  /// 是为了换芯片时对照，不要在下载路径里发它。
  static const int transferStartJl = 0x08;

  /// 准备传输（Telink 芯片）：仅路径。本卡无应答，见 [transferPrepareJl]
  static const int transferPrepareTelink = 0x43;

  /// 启动传输：命令码 0x00，数据 `[0x08, 0x00]`，整帧
  /// `FF 55 AA 02 00 08 00` —— **这是本卡唯一可用的下载启动帧**。
  ///
  /// 文档 §8.5 把 `0x00` 标成「Telink 芯片启动」，并在「附加数据」里直接写了
  /// 完整帧 `FF 55 AA 02 00 08 00`；换句话说它不是「Telink 专用」，而是
  /// 「0x08 启动命令被当成 2 字节参数塞进了 0x00 帧」。设备随后按
  /// NUS notify 推 488B 定长块。
  ///
  /// **厂商 Demo 独立佐证**（2026-10-06）：`com.xyrix.ble_demo`
  /// 「命令面板 → 快捷命令 → 启动传输」往输入框里预填的就是
  /// `FF55AA02000800`，与我们穷举出来的那一格逐字节相同。
  ///
  /// 名字里的 Telink 同样只是文档分组，保留原名以免和文档对不上号。
  static const int transferStartTelink = 0x00;

  /// WiFi 传输触发（断点续传）：路径 hex + 4 字节大端断点
  static const int wifiTransferResume = 0x46;

  /// 停止 WiFi 传输
  static const int wifiTransferStop = 0x47;

  /// 停止 BLE 传输
  static const int bleTransferStop = 0x48;

  /// 查询存储空间。实测响应 8 字节 = `[4B 总容量][4B 剩余容量]`，大端，**单位 KB**
  /// （同一张卡读到 `01 d1 d9 00` / `01 c3 2b 40` = 29.1 GB / 28.2 GB，
  /// 与 31 个 WAV 合计约 0.9 GB 占用自洽；按字节解释只有 29 MB，装不下）
  static const int queryStorage = 0x2E;

  // ---- OPUS 录音 ----
  // 实测 0x50/0x52 无回执；0x53 无回执但确实停流（0x1D 单发不会停，见 adapter）
  static const int opusStart = 0x50;
  static const int opusPause = 0x51;
  static const int opusResume = 0x52;
  static const int opusEnd = 0x53;

  /// OPUS 实时数据推送标记帧（0x54，真机抓包实证）：`FF 55 AA 00 54` 后跟自描述数据包，
  /// 包内以「8 字节子记录头 + 末字节 0x48」分隔一条音频子记录；文档未列出此命令码。
  ///
  /// 已实证的部分：**序列号逐包 +1**（实测 489 包连续、0 跳变），所以「有没有丢包」
  /// 可判。未实证的部分：子记录头的字节布局——曾按 `[1B 子记录长度][8B 子记录头]
  /// [音频][2B CRC]` 建模，能在一段 43,456B 的真机存档上连走 136 条记录，
  /// 到偏移 9489 就对不上了（子记录头并非恒为 7×00+0x48）。
  /// 结论：**别照着这个注释去写解码器**，导出可播放的 opus 需要厂商容器规格。
  static const int opusData = 0x54;

  static const int opusDiscard = 0x55;

  // ---- 工厂模式（SDK 文档 §8.13）----
  /// 设置 WiFi SSID 和密码。载荷格式文档只写「WiFi 配置信息」，未给分隔规则。
  ///
  /// 为什么值得单独试：`0x20/0x21` 对本卡永远只回一帧 `[01]`，而 `[01]` 同样
  /// 出现在 `0x23 关 WiFi` 上——它是「命令收到」的通用回执，不代表热点真开起来了。
  /// 若出厂就没写 WiFi 凭证，那「回 [01] 但扫不到 AP」正是应有的形状。
  static const int setWifiCredentials = 0xF1;

  /// 关闭 WiFi 模块（工厂）
  static const int closeWifiModule = 0xF3;

  /// 设置板卡 SN 号——**真机上没测过，写错就是一次不可恢复的出厂信息破坏，
  /// 探测台不在任何等级里发它**
  static const int setSerialNumber = 0xF4;

  /// 设置蓝牙名称（工厂），与 [setBtName] 同义、走的是产线通道
  static const int factorySetBtName = 0xF6;
}

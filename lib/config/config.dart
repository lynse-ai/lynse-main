/// 全局开关配置（助手版仅保留硬件联调脚手架；登录/微信配置已随旧链路移除）。
class Config {
  /// Xyrix 自驱动联调：连接成功后自动执行下载探测，
  /// 结果写入 Documents/xyrix_selftest_report.txt 供远程拉取验证。
  /// 2026-09-30 下载闭环验证完成，已关闭；需要远程复测时再置 true。
  /// 注意：开启后每次连接（含冷启动自动重连）都会自动跑一遍下载探测。
  static const bool selfTestXyrix = bool.fromEnvironment('XYRIX_SELFTEST');

  /// Xyrix SDK 全命令面探测台等级（`--dart-define=XYRIX_PROBE=<1..5>`）。
  /// 0 = 关闭。分级与破坏性约束见 `lib/core/hardware/xyrix/xyrix_probe.dart`。
  static const int xyrixProbeLevel = int.fromEnvironment(
    'XYRIX_PROBE',
    defaultValue: 0,
  );

  /// 只跑这一等级的步骤（`--dart-define=XYRIX_PROBE_ONLY=4`）。
  /// 用在「前面的命令会把固件打进不应答状态」的隔离实验上，例如 0x24。
  static const int xyrixProbeOnly = int.fromEnvironment(
    'XYRIX_PROBE_ONLY',
    defaultValue: 0,
  );

  /// 联调期运行时可调值：默认继承下面的编译期开关，可被设备上的探测计划文件
  /// 第二行覆盖。一次出包跑完一组实验，不用逐个实验重编。
  /// 因此它们不是 const。

  /// 下载实验选第几个（按大小升序的）文件：0 = 最小。
  /// 别选太大——BLE 上一张 96MB 的卡要传几十分钟，联调取几十到几百 KB 级即可。
  static int downloadIndex = 0;

  /// 按文件名子串选下载目标（厂商 Demo 实测能流式下载 `2026-10-05-23-12-07.wav`，
  /// 而我们所有失败实验打的是 8 月的老文件——必须能用同一个文件做 A/B）
  static String downloadNameContains = '';

  /// 下载实验取设备列表里的第一个文件（实测列表按时间倒序返回，第一个即最新，
  /// 也就是 App 刚录出来的那一条）——老文件读不出时用来区分「文件问题」还是「卡问题」
  static bool downloadNewest = false;

  /// 快传替身服务器 `ip:port`（计划文件第二行 `tcp=192.168.1.11:5000`）。
  /// 厂商的热点启用规则还没给，用它把「开热点 + 入网」两步跳过，
  /// 单独验 0x46→TCP→.part→finalize→完整性 这条数据通路。空 = 走真实热点流程。
  static String wifiServerOverride = '';

  /// 设备热点的**带外参数** `SSID:密码`（计划文件第二行 `ap=AP_xxxxxxxx:口令`，
  /// 真值只写进手机上那份探测计划，不进仓库）。
  ///
  /// 2026-10-06 实测 + 厂商文档 §8.11 一致：`0x21 开启热点并打开 TCP 服务器`
  /// 附加数据为空、也只回一个状态字节，协议里**不存在**「设备经蓝牙把 SSID/密码
  /// 下发给 App」这一步——SSID/密码是带外信息。2026-10-21 厂商给了口径：
  /// AP 名 `AP_` + 一串数字、密码固定，且真机已实测能入网并拿到该网段地址。
  /// 所以真实链路要跑通，必须由调用方把这两个值喂进来。
  /// 只在 Adapter 内部用于入网，绝不写进公共契约、日志或结论字符串。
  /// 空 = 仍按「等设备回传凭证」的老路径（拿不到就明确报缺参数）。
  static String wifiApCredential = '';

  /// 快传 TCP 端点白名单 `ip[:port]`（计划文件第二行 `host=192.168.1.80:5000`）。
  /// 与 [wifiServerOverride] 的区别：这个**不跳过**开热点与入网，只把要拨的
  /// 地址收窄——真机上家里路由器会应答 `192.168.1.1:80` 却不推数据，
  /// 不收窄就会把路由器的端口误当成卡的 TCP 服务器。
  static String wifiTcpTarget = '';

  /// GATT 勘察时额外请求的 MTU（0 = 不请求）。连接流程本身已按文档请求 512，
  /// 这个只用于「换一种 MTU 再试批量下发」的实验（计划文件 `mtu=517`）。
  static int dlRequestMtu = 0;
}

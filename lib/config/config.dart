/// 全局开关配置（助手版仅保留硬件联调脚手架；登录/微信配置已随旧链路移除）。
class Config {
  /// Xyrix 自驱动联调：连接成功后自动执行下载探测，
  /// 结果写入 Documents/xyrix_selftest_report.txt 供远程拉取验证。
  /// 2026-09-30 下载闭环验证完成，已关闭；需要远程复测时再置 true。
  static const bool selfTestXyrix = false;
}

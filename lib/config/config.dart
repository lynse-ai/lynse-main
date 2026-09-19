class Config {
  static var appId = "wx938d748bbf593aef";
  static var universalLink = "https://lynse-ai.com/";
  // https://qtcampus.cn/

  /// 跳过登录直接进入 lynse 新版首页。
  /// 2026-09-18 起临时在 release 也生效（真机测试用），恢复登录时
  /// 在 starup_controller 里重新加上 kDebugMode 限制。
  static const bool debugSkipLogin = true;
}

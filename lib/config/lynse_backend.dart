/// Lynse 后端接入配置。
///
/// TODO(联调): 后端已建好，拿到正式环境信息后替换以下占位值，
/// 并与后端确认契约细节（差异统一收敛在 LynseApi 一层）。
library;

abstract final class LynseBackend {
  /// 业务 API 基地址（占位：待替换为已建好的后端地址）
  static const String apiBaseUrl = 'https://api.lynse.example.com';

  /// 统一 envelope 成功码（lynse-desktop 契约：{code, data, msg}，code==200 成功）
  static const int successCode = 200;
}

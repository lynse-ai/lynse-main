// 清理非法字符
String cleanBase64(String input) {
  return input.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
}

// 自动补全或修正填充
String fixPadding(String input) {
  String sanitized = input.replaceAll('=', '');
  int padding = (4 - (sanitized.length % 4)) % 4;
  return sanitized + ('=' * padding);
}

// 解码
String convertUrlSafeToStandard(String input) {
  return input.replaceAll('-', '+').replaceAll('_', '/');
}

// 编码
String convertStandardToUrlSafe(String input) {
  return input.replaceAll('+', '-').replaceAll('/', '_');
}

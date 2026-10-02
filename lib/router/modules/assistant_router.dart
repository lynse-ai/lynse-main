/// 助手版路由模块。
library;

import 'package:dting/features/assistant/assistant_chat_page.dart';
import 'package:dting/features/shell/assistant_shell_page.dart';
import 'package:get/get.dart';

class AssistantRouter {
  /// 助手版外壳（今日 / 录音 / 设备 / 任务 四 tab + 常驻助手输入条）
  static final shell = '/assistantShell';

  /// 助手全屏会话
  static final chat = '/assistantChat';

  static final pages = [
    GetPage(
      name: shell,
      page: () => const AssistantShellPage(),
      binding: AssistantShellBinding(),
    ),
    GetPage(name: chat, page: () => const AssistantChatPage()),
  ];
}

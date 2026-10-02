/// 助手版路由模块。
library;

import 'package:dting/features/assistant/assistant_chat_page.dart';
import 'package:dting/features/recordings/recording_detail_page.dart';
import 'package:dting/features/shell/assistant_shell_page.dart';
import 'package:dting/ui/component_demo_page.dart';
import 'package:get/get.dart';

class AssistantRouter {
  /// 助手版外壳（今日 / 录音 / 设备 / 任务 四 tab + 常驻助手输入条）
  static final shell = '/assistantShell';

  /// 助手全屏会话
  static final chat = '/assistantChat';

  /// 录音详情（播放条 + 转写 / 时间轴 / 纪要）
  static final recordingDetail = '/recordingDetail';

  /// 设计系统 demo（验收用）
  static final uiDemo = '/uiDemo';

  static final pages = [
    GetPage(
      name: shell,
      page: () => const AssistantShellPage(),
      binding: AssistantShellBinding(),
    ),
    GetPage(name: chat, page: () => const AssistantChatPage()),
    GetPage(name: recordingDetail, page: () => const RecordingDetailPage()),
    GetPage(name: uiDemo, page: () => const ComponentDemoPage()),
  ];
}

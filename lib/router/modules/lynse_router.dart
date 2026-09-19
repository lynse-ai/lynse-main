/// lynse 新版 UI 路由模块。
library;

import 'package:dting/pages/lynse/lynse_recording_detail_page.dart';
import 'package:dting/pages/lynse/lynse_shell_page.dart';
import 'package:get/get.dart';

class LynseRouter {
  /// 新版外壳（主页 / 设备 / 记录 三 tab）
  static final shell = '/lynseShell';

  /// 录音详情（转写 / 时间轴 / 纪要）
  static final recordingDetail = '/lynseRecordingDetail';

  static final pages = [
    GetPage(
      name: shell,
      page: () => const LynseShellPage(),
      binding: LynseShellBinding(),
    ),
    GetPage(name: recordingDetail, page: () => const LynseRecordingDetailPage()),
  ];
}

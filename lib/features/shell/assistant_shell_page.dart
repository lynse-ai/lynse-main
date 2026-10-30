/// 助手版外壳：今日 / 录音 / 设备 / 任务 四 tab + 常驻助手输入条。
///
/// 输入条是整个 app 的交互动核心（对标 OpenMUSE 的常驻 chat bar）：
/// 点击展开全屏会话。
library;

import 'dart:async';

import 'package:dting/core/services/device_session_controller.dart';
import 'package:dting/core/services/playback_service.dart';
import 'package:dting/core/services/recording_library.dart';
import 'package:dting/core/services/assistant_service.dart';
import 'package:dting/core/services/task_center.dart';
import 'package:dting/features/device/device_page.dart';
import 'package:dting/features/recordings/recordings_page.dart';
import 'package:dting/features/tasks/tasks_page.dart';
import 'package:dting/features/today/today_page.dart';
import 'package:dting/router/modules/assistant_router.dart';
import 'package:dting/ui/components.dart';
import 'package:dting/ui/glass.dart';
import 'package:dting/ui/liquid_duck.dart';
import 'package:dting/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AssistantShellBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<DeviceSessionController>()) {
      DeviceSessionController.init().bootstrap();
    }
    RecordingLibrary.init().bootstrap();
    PlaybackService.init().boot();
    TaskCenter.init().bootstrap();
    AssistantService.init().bootstrap();
  }
}

class AssistantShellPage extends StatefulWidget {
  const AssistantShellPage({super.key});

  @override
  State<AssistantShellPage> createState() => _AssistantShellPageState();
}

class _AssistantShellPageState extends State<AssistantShellPage> {
  int _index = 0;

  static const _titles = ['今日', '录音', '设备', '任务'];

  StreamSubscription<SessionNotice?>? _noticeSub;

  @override
  void initState() {
    super.initState();
    // 进入外壳自动重连上次连接的设备（直连失败不打扰，结果走 sessionNotice）
    DeviceSessionController.instance.autoReconnect();
    // 硬件层不弹任何 UI，连接结果/校验失败等需要用户知道的事都从这里出去
    _noticeSub = DeviceSessionController.instance.sessionNotice.stream
        .where((n) => n != null)
        .listen((n) {
      if (!mounted || n == null) return;
      Get.snackbar(n.title, n.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: n.isError ? LColors.dangerBg : LColors.sky,
          colorText: n.isError ? LColors.danger : LColors.text);
    });
  }

  @override
  void dispose() {
    _noticeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 光斑层必须在 Scaffold 之外、且 Scaffold 透明：
    // 否则 dock 身后是实心 canvas，再怎么 blur 也透不出东西，看着就是张白卡
    return LGlassBackdrop(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              // 玻璃层走 flexibleSpace：见 LGlassAppBarLayer 的说明
              flexibleSpace: const LGlassAppBarLayer(),
              title: Text(_titles[_index]),
              actions: [
                IconButton(
                  tooltip: '设计系统 Demo',
                  icon: const Icon(Icons.palette_outlined,
                      size: 20, color: LColors.muted),
                  onPressed: () => Get.toNamed('/uiDemo'),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: IndexedStack(
              index: _index,
              children: const [
                TodayPage(),
                RecordingsPage(),
                DevicePage(),
                TasksPage(),
              ],
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 常驻助手输入条：点击进入全屏会话
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      LSpacing.xl, 4, LSpacing.xl, 10),
                  child: _AssistantBar(
                    onTap: () => Get.toNamed(AssistantRouter.chat),
                  ),
                ),
                // 悬浮 dock：脱离底边 + 透明填充 + 投影
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      LSpacing.xl, 0, LSpacing.xl, 14),
                  child: LGlass(
                    floating: true,
                    shadow: true,
                    radius: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: NavigationBar(
                      selectedIndex: _index,
                      onDestinationSelected: (i) => setState(() => _index = i),
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.wb_sunny_outlined),
                          selectedIcon: Icon(Icons.wb_sunny),
                          label: '今日',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.graphic_eq_outlined),
                          selectedIcon: Icon(Icons.graphic_eq),
                          label: '录音',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.headphones_outlined),
                          selectedIcon: Icon(Icons.headphones),
                          label: '设备',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.checklist_outlined),
                          selectedIcon: Icon(Icons.checklist),
                          label: '任务',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 悬浮液态玻璃鸭子：盖在 dock 之上，可拖动，点击进会话
          LDuckBubble(onTap: () => Get.toNamed(AssistantRouter.chat)),
        ],
      ),
    );
  }
}

/// 常驻助手输入条（展示态，点击进入会话）。
class _AssistantBar extends StatelessWidget {
  const _AssistantBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LRadius.button),
      child: LGlass(
        floating: true,
        shadow: true,
        radius: LRadius.button,
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 17, color: LColors.blueDark),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('问你的助手…', style: LType.muted),
                ),
                LButton(
                    label: '问', primary: true, small: true, onPressed: onTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// lynse 风格外壳：主页 / 设备 / 记录 三个 tab（参考 lynse-desktop 信息架构）。
library;

import 'package:dting/controller/device_session_controller.dart';
import 'package:dting/pages/lynse/lynse_devices_tab.dart';
import 'package:dting/pages/lynse/lynse_home_tab.dart';
import 'package:dting/pages/lynse/lynse_recordings_tab.dart';
import 'package:dting/styles/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LynseShellBinding extends Bindings {
  @override
  void dependencies() {
    // DeviceSessionController 是 permanent 单例，重复进入 shell 不会重建
    if (!Get.isRegistered<DeviceSessionController>()) {
      DeviceSessionController.init().bootstrap();
    }
  }
}

class LynseShellPage extends StatefulWidget {
  const LynseShellPage({super.key});

  @override
  State<LynseShellPage> createState() => _LynseShellPageState();
}

class _LynseShellPageState extends State<LynseShellPage> {
  int _index = 0;

  static const _titles = ['主页', '设备', '记录'];

  @override
  Widget build(BuildContext context) {
    final s = context.lynse;
    return Scaffold(
      backgroundColor: s.background,
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: '我的',
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: s.brand.withValues(alpha: 0.15),
              child: Text(
                'L',
                style: TextStyle(fontSize: 12, color: s.brand),
              ),
            ),
            onPressed: () => Get.toNamed('/my'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          LynseHomeTab(),
          LynseDevicesTab(),
          LynseRecordingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: s.card,
          indicatorColor: s.brand.withValues(alpha: 0.12),
          surfaceTintColor: Colors.transparent,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '主页',
            ),
            NavigationDestination(
              icon: Icon(Icons.headphones_outlined),
              selectedIcon: Icon(Icons.headphones),
              label: '设备',
            ),
            NavigationDestination(
              icon: Icon(Icons.graphic_eq_outlined),
              selectedIcon: Icon(Icons.graphic_eq),
              label: '记录',
            ),
          ],
        ),
      ),
    );
  }
}

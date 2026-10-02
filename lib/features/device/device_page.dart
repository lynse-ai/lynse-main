/// 设备屏（过渡版）：Phase 4 之前暂嵌旧 lynse 设备 tab 保持可用。
library;

import 'package:dting/pages/lynse/lynse_devices_tab.dart';
import 'package:flutter/material.dart';

class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LynseDevicesTab();
  }
}

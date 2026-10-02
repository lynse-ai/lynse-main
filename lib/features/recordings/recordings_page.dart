/// 录音库屏（过渡版）：Phase 3 之前暂嵌旧 lynse 记录 tab 保持可用。
library;

import 'package:dting/pages/lynse/lynse_recordings_tab.dart';
import 'package:flutter/material.dart';

class RecordingsPage extends StatelessWidget {
  const RecordingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LynseRecordingsTab();
  }
}

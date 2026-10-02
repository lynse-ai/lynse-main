/// 任务中心屏（占位）：Phase 5 落地统一任务状态机（下载/导入/转写/生成）。
library;

import 'package:dting/ui/components.dart';
import 'package:flutter/material.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(25),
      children: const [
        LCard(
          child: LEmpty(
            icon: Icons.checklist,
            title: '暂无任务',
            message: '下载、转写、生成任务会在这里排队与展示进度',
          ),
        ),
      ],
    );
  }
}

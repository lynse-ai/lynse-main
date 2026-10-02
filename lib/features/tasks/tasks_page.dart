/// 任务中心屏：进行中任务（实时进度）+ 历史流水。
library;

import 'package:dting/core/services/task_center.dart';
import 'package:dting/ui/components.dart';
import 'package:dting/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final center = TaskCenter.instance;
    return Obx(() {
      final active = center.activeTasks;
      final history = center.history;
      if (active.isEmpty && history.isEmpty) {
        return ListView(
          padding: const EdgeInsets.all(LSpacing.xl),
          children: const [
            SizedBox(height: 80),
            const LCard(
              child: LEmpty(
                icon: Icons.checklist,
                title: '暂无任务',
                message: '下载、转写、生成任务会在这里排队与展示进度',
              ),
            ),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.all(LSpacing.xl),
        children: [
          if (active.isNotEmpty) ...[
            const LSectionHeading(label: '进行中'),
            const SizedBox(height: 12),
            ...active.map((t) => _ActiveTaskCard(task: t)),
            const SizedBox(height: LSpacing.xl),
          ],
          if (history.isNotEmpty) ...[
            LSectionHeading(
              label: '最近记录',
              trailing: TextButton(
                onPressed: center.clearHistory,
                child: const Text('清空', style: LType.small),
              ),
            ),
            const SizedBox(height: 12),
            LCard(
              child: Column(
                children: [
                  ...history.map((t) => _HistoryRow(task: t)),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _ActiveTaskCard extends StatelessWidget {
  const _ActiveTaskCard({required this.task});

  final TaskEntry task;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LChip(label: task.typeLabel, tint: LColors.sky),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LType.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text('${task.progress}%', style: LType.small),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (task.progress / 100).clamp(0.0, 1.0),
                backgroundColor: LColors.line,
                color: LColors.blueDark,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.task});

  final TaskEntry task;

  @override
  Widget build(BuildContext context) {
    final (label, tint, icon) = switch (task.status) {
      TaskStatus.success => ('成功', LColors.green, Icons.check_circle_outline),
      TaskStatus.failed => ('失败', LColors.dangerBg, Icons.error_outline),
      _ => ('取消', LColors.secondary, Icons.cancel_outlined),
    };
    final d = task.updatedAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: task.status == TaskStatus.failed ? LColors.danger : LColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LType.muted.copyWith(color: LColors.text),
                ),
                Text(
                  '${task.typeLabel} · ${d.month}月${d.day}日 ${d.hour}:${d.minute.toString().padLeft(2, '0')}'
                  '${task.error != null ? ' · ${task.error}' : ''}',
                  style: LType.small,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          LChip(label: label, tint: tint),
        ],
      ),
    );
  }
}

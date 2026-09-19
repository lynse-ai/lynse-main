/// lynse 风格页面共享小组件（参考 lynse-desktop 组件形态）
library;

import 'package:dting/styles/theme.dart';
import 'package:flutter/material.dart';

/// 圆角卡片（对应桌面端 card，10px 基准圆角 xl）
class LynseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const LynseCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.lynse;
    return Material(
      color: s.card,
      borderRadius: LynseRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: LynseRadius.card,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: LynseRadius.card,
            border: Border.all(color: s.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 状态胶囊（recording / paused / connected ...）
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡片区块标题行（标题 + 右侧操作）
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final s = context.lynse;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: s.foreground,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// 空态（对应桌面端 EmptyState）
class LynseEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const LynseEmpty({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.lynse;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: s.mutedForeground),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 14, color: s.foreground)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: s.mutedForeground),
            ),
          ],
        ],
      ),
    );
  }
}

/// 实时电平条（录音中 12 根竖条，对齐桌面端设备页电平表）
class LevelMeter extends StatelessWidget {
  final List<double> levels; // 0.0 - 1.0

  const LevelMeter({super.key, required this.levels});

  @override
  Widget build(BuildContext context) {
    final s = context.lynse;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(levels.length, (i) {
        final level = levels[i];
        final color = level > 0.9
            ? LynseColors.danger
            : level > 0.7
                ? LynseColors.warning
                : s.brand;
        return Container(
          width: 3,
          height: 6 + 30 * level,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.35 + 0.65 * level),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

/// 助手版基础组件库——按 OpenMUSE ui.tsx 的 12 个组件 1:1 复刻到 Flutter。
///
/// 命名加 L 前缀（Lynse）避免与 Material 内置组件混淆。
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

// ---------------------------------------------------------------------------
// Button / IconButton
// ---------------------------------------------------------------------------

/// 胶囊按钮：主样式蓝底深蓝字，次样式灰底（OpenMUSE Button）。
class LButton extends StatelessWidget {
  const LButton({
    super.key,
    required this.label,
    this.icon,
    this.primary = false,
    this.onPressed,
    this.small = false,
  });

  final String label;
  final IconData? icon;
  final bool primary;
  final VoidCallback? onPressed;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? LColors.blueDark : LColors.text;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: primary ? LColors.blue : LColors.secondary,
        foregroundColor: fg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LRadius.button)),
        padding: EdgeInsets.symmetric(
          horizontal: small ? 12 : 17,
          vertical: small ? 6 : 10,
        ),
        minimumSize: Size(0, small ? 32 : 42),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: small ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// 图标盒按钮：42x42 天空蓝圆角方块（OpenMUSE iconBox + IconButton）。
class LIconButton extends StatelessWidget {
  const LIconButton({super.key, required this.icon, this.onPressed, this.tint});

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final boxColor = tint ?? LColors.sky;
    final fg = tint == null ? LColors.blueDark : LColors.text;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(LRadius.iconBox),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: boxColor,
          borderRadius: BorderRadius.circular(LRadius.iconBox),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: fg),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card / Chip / SectionHeading / LinkRow / Empty / ErrorNotice
// ---------------------------------------------------------------------------

/// 基础卡片：白底、23 圆角、20 内边距（OpenMUSE s.card）。
class LCard extends StatelessWidget {
  const LCard({super.key, required this.child, this.padding, this.color});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(LSpacing.lg),
      decoration: BoxDecoration(
        color: color ?? LColors.card,
        borderRadius: BorderRadius.circular(LRadius.card),
        border: Border.all(color: LColors.line),
      ),
      child: child,
    );
  }
}

/// 小胶囊标签：浅底小字（OpenMUSE Chip）。
class LChip extends StatelessWidget {
  const LChip({super.key, required this.label, this.tint});

  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint ?? LColors.canvas,
        borderRadius: BorderRadius.circular(LRadius.chip),
        border: tint == null ? Border.all(color: LColors.line) : null,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: LColors.muted),
      ),
    );
  }
}

/// 区块标题：小号大写标签 + 可选右侧动作（OpenMUSE SectionHeading）。
class LSectionHeading extends StatelessWidget {
  const LSectionHeading({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label.toUpperCase(), style: LType.label)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// 列表行：左图标盒 + 标题/副标题 + 右侧箭头（OpenMUSE LinkRow）。
class LLinkRow extends StatelessWidget {
  const LLinkRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LRadius.button),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            LIconButton(icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: LType.body.copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: LType.small),
                  ],
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right, size: 18, color: LColors.muted),
          ],
        ),
      ),
    );
  }
}

/// 空状态：图标盒 + 标题 + 说明（OpenMUSE Empty）。
class LEmpty extends StatelessWidget {
  const LEmpty({super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LIconButton(icon: icon, tint: LColors.sky),
            const SizedBox(height: 14),
            Text(title, style: LType.heading),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, style: LType.muted, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

/// 错误条：浅红底圆角条（OpenMUSE ErrorNotice）。
class LErrorNotice extends StatelessWidget {
  const LErrorNotice({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(LSpacing.md),
      decoration: BoxDecoration(
        color: LColors.dangerBg,
        borderRadius: BorderRadius.circular(LRadius.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: LColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message!, style: LType.small.copyWith(color: LColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Field / CheckRow
// ---------------------------------------------------------------------------

/// 带标签的输入框（OpenMUSE Field）。
class LField extends StatelessWidget {
  const LField({super.key, required this.label, this.controller, this.hint, this.maxLines});

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: LType.label),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: maxLines ?? 1,
          style: LType.body.copyWith(fontSize: 16),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

/// 勾选行（OpenMUSE CheckRow）。
class LCheckRow extends StatelessWidget {
  const LCheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: value ? LColors.blueDark : LColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: LType.body)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet
// ---------------------------------------------------------------------------

/// 居中弹层：26 圆角画布卡 + 遮罩（OpenMUSE Sheet 的 mobile 形态）。
Future<T?> showLSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(LSpacing.lg),
        decoration: BoxDecoration(
          color: LColors.canvas,
          borderRadius: BorderRadius.circular(LRadius.sheet),
          border: Border.all(color: LColors.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title, style: LType.heading),
              const SizedBox(height: LSpacing.md),
            ],
            Flexible(child: builder(context)),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Mascot
// ---------------------------------------------------------------------------

/// 助手吉祥物占位：天空蓝圆脸 + 两点眼睛 + 微笑（自绘，后续替换正式素材）。
class LMascot extends StatelessWidget {
  const LMascot({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MascotPainter()),
    );
  }
}

class _MascotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final facePaint = Paint()..color = LColors.sky;
    final featurePaint = Paint()..color = LColors.blueDark;
    final stroke = Paint()
      ..color = LColors.blueDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    canvas.drawCircle(center, radius, facePaint);
    canvas.drawCircle(center, radius, stroke);

    // 眼睛
    final eyeDy = center.dy - radius * 0.18;
    final eyeDx = radius * 0.38;
    final eyeR = size.width * 0.035;
    canvas.drawCircle(Offset(center.dx - eyeDx, eyeDy), eyeR, featurePaint);
    canvas.drawCircle(Offset(center.dx + eyeDx, eyeDy), eyeR, featurePaint);

    // 微笑
    final smile = Path()
      ..moveTo(center.dx - radius * 0.4, center.dy + radius * 0.22)
      ..quadraticBezierTo(
        center.dx,
        center.dy + radius * 0.55,
        center.dx + radius * 0.4,
        center.dy + radius * 0.22,
      );
    canvas.drawPath(smile, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

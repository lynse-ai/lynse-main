import 'package:dting/utils/color_util.dart';
import 'package:flutter/widgets.dart';

class GradientBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final radius = 12.0;

    final Paint paint =
        Paint()
          ..shader = LinearGradient(
            colors: [
              // ColorUtil.fromHexString("#404040", 0.5),
              // ColorUtil.fromHexString("#404040", 0.35),
              // ColorUtil.fromHexString("#FFFFFF", 0.5),
              // ColorUtil.fromHexString("#FFFFFF", 0.5),
              // ColorUtil.fromHexString("#404040", 0.35),
              // ColorUtil.fromHexString("#F9F9F9"),
              // ColorUtil.fromHexString("#FFFFFF", 0.5),
              // ColorUtil.fromHexString("#F9F9F9", 0.5),
              ColorUtil.fromHexString("#F9F9F9"),
              ColorUtil.fromHexString("#404040", 0.35),
              ColorUtil.fromHexString("#FFFFFF", 0.5),
              ColorUtil.fromHexString("#FFFFFF", 0.5),
              ColorUtil.fromHexString("#F9F9F9", 0.5),
              ColorUtil.fromHexString("#404040", 0.35),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    final rRect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

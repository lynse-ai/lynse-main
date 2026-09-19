import 'dart:math';

import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart'; 
import 'package:get/get.dart';

class AudioWaveformSlider extends StatefulWidget {
  AudioWaveformSlider({
    super.key,
    required this.progress,
    required this.onChanged,
  });
  final double progress; // 0.0 ~ 1.0 当前进度
  final ValueChanged<double> onChanged;

  @override
  State<AudioWaveformSlider> createState() => _CanvasCustomTextState();
}

class _CanvasCustomTextState extends State<AudioWaveformSlider> {
  List<double> sounds = [];
  @override
  void initState() {
    super.initState();
    setState(() { 
      final random = Random();
      sounds = List.generate(
        Get.width.toInt(),
        (_) => random.nextDouble() * 2.5,
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final local = box.globalToLocal(details.globalPosition);
        final ratio = local.dx.clamp(0.0, box.size.width) / box.size.width;
        widget.onChanged(ratio);
      },
      child: SizedBox(
        width: Get.width,
        child: CustomPaint(
          painter: _WaveformSliderPainter(sounds, widget.progress),
          size: Size(Get.width, 50),
        ),
      ),
    );
  }
}

class _WaveformSliderPainter extends CustomPainter {
  final List<double> samples;
  final double progress;

  _WaveformSliderPainter(this.samples, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paintActive =
        Paint()
          ..color = ColorUtil.fromHexString("#5C4EBE")
          ..strokeCap = StrokeCap.round;

    final paintInactive =
        Paint()
          ..color = ColorUtil.fromHexString("#7E8492", 0.6)
          ..strokeCap = StrokeCap.round;

    // 每根柱子的宽度 & 间距
    const barWidth = 1.5;
    const spacing = 2.0;

    // 根据容器宽度能放下多少根柱子
    final barCount = (size.width / (barWidth + spacing)).floor();

    for (int i = 0; i < barCount; i++) {
      final sampleIndex = (i / barCount * samples.length).floor();
      final rawValue = samples[sampleIndex];

      // 🔑 归一化，保证不会超出容器
      final normalized = (rawValue / 2.5).clamp(0.0, 1.0);
      final barHeight = normalized * size.height;

      final x = i * (barWidth + spacing);
      final isActive = (x / size.width) < progress;
      final paint = isActive ? paintActive : paintInactive;

      final rect = Rect.fromLTWH(
        x,
        (size.height - barHeight) / 2, // 居中
        barWidth,
        barHeight,
      );

      canvas.drawRRect(RRect.fromRectXY(rect, 2, 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformSliderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.samples != samples;
  }
}

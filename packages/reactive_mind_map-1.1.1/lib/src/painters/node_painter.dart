import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../enums/node_shape.dart';

/// 다양한 모양의 노드를 그리는 페인터
class NodePainter {
  /// 지정된 모양으로 노드를 그림
  static void paintNode({
    required Canvas canvas,
    required Rect rect,
    required NodeShape shape,
    required Paint fillPaint,
    Paint? borderPaint,
  }) {
    switch (shape) {
      case NodeShape.roundedRectangle:
        _paintRoundedRectangle(canvas, rect, fillPaint, borderPaint);
        break;
      case NodeShape.circle:
        _paintCircle(canvas, rect, fillPaint, borderPaint);
        break;
      case NodeShape.rectangle:
        _paintRectangle(canvas, rect, fillPaint, borderPaint);
        break;
      case NodeShape.diamond:
        _paintDiamond(canvas, rect, fillPaint, borderPaint);
        break;
      case NodeShape.hexagon:
        _paintHexagon(canvas, rect, fillPaint, borderPaint);
        break;
      case NodeShape.ellipse:
        _paintEllipse(canvas, rect, fillPaint, borderPaint);
        break;
    }
  }

  /// 둥근 사각형 그리기
  static void _paintRoundedRectangle(
    Canvas canvas,
    Rect rect,
    Paint fillPaint,
    Paint? borderPaint,
  ) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(rrect, fillPaint);
    if (borderPaint != null) {
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  /// 원형 그리기
  static void _paintCircle(
    Canvas canvas,
    Rect rect,
    Paint fillPaint,
    Paint? borderPaint,
  ) {
    final center = rect.center;
    final radius = math.min(rect.width, rect.height) / 2;
    canvas.drawCircle(center, radius, fillPaint);
    if (borderPaint != null) {
      canvas.drawCircle(center, radius, borderPaint);
    }
  }

  /// 사각형 그리기
  static void _paintRectangle(
    Canvas canvas,
    Rect rect,
    Paint fillPaint,
    Paint? borderPaint,
  ) {
    canvas.drawRect(rect, fillPaint);
    if (borderPaint != null) {
      canvas.drawRect(rect, borderPaint);
    }
  }

  /// 다이아몬드 그리기
  static void _paintDiamond(
    Canvas canvas,
    Rect rect,
    Paint fillPaint,
    Paint? borderPaint,
  ) {
    final path = Path();
    final center = rect.center;
    final halfWidth = rect.width / 2;
    final halfHeight = rect.height / 2;

    path.moveTo(center.dx, center.dy - halfHeight); // 상단
    path.lineTo(center.dx + halfWidth, center.dy); // 우측
    path.lineTo(center.dx, center.dy + halfHeight); // 하단
    path.lineTo(center.dx - halfWidth, center.dy); // 좌측
    path.close();

    canvas.drawPath(path, fillPaint);
    if (borderPaint != null) {
      canvas.drawPath(path, borderPaint);
    }
  }

  /// 육각형 그리기
  static void _paintHexagon(
    Canvas canvas,
    Rect rect,
    Paint fillPaint,
    Paint? borderPaint,
  ) {
    final path = Path();
    final center = rect.center;
    final size = math.min(rect.width, rect.height) / 2;

    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i;
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    if (borderPaint != null) {
      canvas.drawPath(path, borderPaint);
    }
  }

  /// 타원 그리기
  static void _paintEllipse(
    Canvas canvas,
    Rect rect,
    Paint fillPaint,
    Paint? borderPaint,
  ) {
    canvas.drawOval(rect, fillPaint);
    if (borderPaint != null) {
      canvas.drawOval(rect, borderPaint);
    }
  }
}

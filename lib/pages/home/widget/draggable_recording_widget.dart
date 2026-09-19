import 'package:dting/store/dting_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class DraggableForRecordingWidget extends StatefulWidget {
  final VoidCallback onTap;
  final DtingStore controller;

  const DraggableForRecordingWidget({
    super.key,
    required this.controller,
    required this.onTap,
  });

  @override
  _DraggableForRecordingWidgetState createState() =>
      _DraggableForRecordingWidgetState();
}

class _DraggableForRecordingWidgetState
    extends State<DraggableForRecordingWidget> {
  final _width = 70.w;
  late Offset position;

  bool isVisible = true;

  @override
  initState() {
    position = Offset(Get.width - _width,600.w);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            // 更新位置，但限制在屏幕边界内
            double newX = position.dx + details.delta.dx;
            double newY = position.dy + details.delta.dy;

            newX = newX.clamp(0.0, screenSize.width - _width);
            newY = newY.clamp(0.0, screenSize.height - 150.w);

            position = Offset(newX, newY);
          });
        },
        onPanEnd: (details) {
          double centerX = screenSize.width / 2;

          // 如果位置靠左就吸附到最左边，否则吸附到最右边
          double finalX =
              (position.dx < centerX) ? 0.0 : screenSize.width - _width;

          position = Offset(finalX, position.dy);
          setState(() {});
        },
        child: GestureDetector(
          onTap: () => widget.onTap(),
          child: Obx(() {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(46.r),
              ),
              child: Image.asset(
                widget.controller.homeBottomStartOrStopIconUrl.value,
                height: 70.w,
                width: 70.w,
              ),
            );
          }),
        ),
      ),
    );
  }
}

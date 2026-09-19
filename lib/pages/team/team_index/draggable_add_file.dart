import 'dart:ui';

import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class DiaLogAddFileWidgetWidget extends StatefulWidget {
  final Function(bool? val) onClick;

  const DiaLogAddFileWidgetWidget({super.key, required this.onClick});

  @override
  _DiaLogAddFileWidgetWidgetState createState() =>
      _DiaLogAddFileWidgetWidgetState();
}

class _DiaLogAddFileWidgetWidgetState extends State<DiaLogAddFileWidgetWidget> {
  var teamFileController = Get.find<TeamFileController>();
  final _width = 70.w;
  late Offset position;

  bool isVisible = true;

  @override
  initState() {
    position = Offset(Get.width - _width, 600.w);
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
          onTap: () {
            if (teamFileController.currentTeam.value.id == "-1" ||
                teamFileController.currentTeam.value.id == "") {
              DialogHelper.showToastDialog("notExistsTeam");
            } else {
              Get.dialog(
                barrierDismissible: true,
                barrierColor: ColorUtil.fromHexString("#161616", 0.4), // 背景颜色
                _diaLogAddFileWidget(onClick: widget.onClick),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(46.r),
            ),
            child: Image.asset(
              "assets/images_v3/team-add-files.png",
              height: 70.w,
              width: 70.w,
            ),
          ),
        ),
      ),
    );
  }

  Widget _diaLogAddFileWidget({required Function(bool? val) onClick}) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // 模糊半径
      child: Container(
        padding: EdgeInsets.only(bottom: 173.w),
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Get.back();
                    onClick(true);
                  },
                  child: Container(
                    height: 36.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 15.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          "assets/images_v3/team-import-file.png",
                          height: 24.w,
                          width: 24.w,
                        ),
                        Text("selectFromFile".tr).descText(fontSize: 13),
                        Image.asset(
                          "assets/images_v3/chevron-down.png",
                          height: 10.w,
                          width: 13.w,
                          color: ColorUtil.fromHexString("#52535D"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.w),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Get.back();
                    onClick(false);
                  },
                  child: Container(
                    height: 36.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 15.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          "assets/images_v3/team-import-phone.png",
                          height: 24.w,
                          width: 24.w,
                        ),
                        Text("selectFromPhone".tr).descText(fontSize: 13),
                        Image.asset(
                          "assets/images_v3/chevron-down.png",
                          height: 10.w,
                          width: 13.w,
                          color: ColorUtil.fromHexString("#52535D"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

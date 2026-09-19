import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class DividerWidget extends GetView {
  const DividerWidget({
    super.key,
    this.height = 1,
    this.spacer = 5,
    this.colors,
  });
  final double height;
  final double spacer;
  final Color? colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: spacer.w),
      child: Divider(
        color: colors ?? ColorUtil.fromHexString("#E7E9EC"),
        height: height.w,
      ),
    );
  }
}

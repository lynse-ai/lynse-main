import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

class BottomBottonWidget extends GetView {
  BottomBottonWidget({
    super.key,
    this.width = 120,
    required this.text,
    required this.backgroundColor,
    required this.ontap,
    this.textColor,
    this.margin = 20,
  });
  final double width;
  final String text;
  Color backgroundColor;
  Color? textColor;
  Callback ontap;
  final double margin;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ontap,
      child: Container(
        alignment: Alignment.center,
        height: 40.w,
        width: width.w,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10.r),
        ),
        margin: EdgeInsets.symmetric(horizontal: margin.w),
        child: Text(text.tr).boldTitle(
          color: textColor ?? ColorUtil.fromHexString("#FFFFFF"),
          fontSize: 16,
        ),
      ),
    );
  }
}

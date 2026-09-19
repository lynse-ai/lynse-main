import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SliderIndicatorBar extends StatelessWidget {
  SliderIndicatorBar({super.key, this.color = "#000000"});
  String color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 8.w, bottom: 8.w),
      child: Center(
        child: Container(
          width: 50.w,
          height: 4.w,
          decoration: BoxDecoration(
            color: ColorUtil.fromHexString(color),
            borderRadius: BorderRadius.circular(5.w),
          ),
        ),
      ),
    );
  }
}

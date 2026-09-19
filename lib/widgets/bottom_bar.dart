import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

import '../utils/color_util.dart';

class BottomBarWidget extends GetView {
  const BottomBarWidget({
    super.key,
    required this.title,
    required this.ontap,
    this.fontsize = 16,
    this.beforeAssname,
    this.borderRadius = 12,
    this.beforeimagesize = 20,
    this.lineheigt = 18.75,
    this.fontweight = FontWeight.w500,
    this.color,
    this.titleColor,
    this.height = 40,
  });
  final String title;
  final String? beforeAssname;
  final Callback ontap;
  final double fontsize;
  final double beforeimagesize;
  final double lineheigt;
  final double borderRadius;
  final FontWeight fontweight;
  final Color? color;
  final Color? titleColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ontap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? ColorUtil.fromHexString('#7857ED'),
          borderRadius: BorderRadius.circular(borderRadius.w),
        ),
        width: 327.w,
        height: height.w,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            beforeAssname != null
                ? Container(
                  padding: EdgeInsets.only(right: 6.w),
                  child: SvgPicture.asset(
                    beforeAssname!,
                    height: beforeimagesize.w,
                    width: beforeimagesize.w,
                  ),
                )
                : SizedBox(),
            Text(
              title.tr,
              style: TextStyle(
                color: titleColor ?? ColorUtil.fromHexString("#FFFFFF"),
                fontWeight: fontweight,
                fontSize: fontsize.w,
                height: lineheigt / fontsize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

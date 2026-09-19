import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

class BottomRowMenuItemWidget extends GetView {
  BottomRowMenuItemWidget({
    super.key,
    required this.text,
    required this.ontap,
    this.assetsName,
    this.textColor = Colors.black,
    this.assetsNameColor = Colors.black,
    this.showArrow = true,
  });
  final String text;
  Color textColor;
  Color assetsNameColor;
  Callback ontap;
  String? assetsName;
  bool showArrow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Get.back();
        ontap();
      },
      child: Container(
        height: 43.w,
        width: double.infinity,
        alignment: Alignment.center,
        margin: EdgeInsets.only(bottom: 15.w),
        decoration: BoxDecoration(
          color: ColorUtil.fromHexString("#FFFFFF"),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Row(
          mainAxisAlignment:
              showArrow
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                assetsName != null
                    ? Container(
                      margin: EdgeInsets.only(left: 16.w, right: 10.w),
                      child: Image.asset(
                        assetsName!,
                        height: 16.w,
                        width: 16.w,
                        color: assetsNameColor,
                      ),
                    )
                    : SizedBox(),
                Text(text.tr).descText(color: textColor, fontSize: 12),
              ],
            ),
            showArrow
                ? Row(
                  children: [
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16.w,
                      color: ColorUtil.fromHexString("#5B5E68"),
                    ),
                    SizedBox(width: 16.w),
                  ],
                )
                : SizedBox(),
          ],
        ),
      ),
    );
  }
}

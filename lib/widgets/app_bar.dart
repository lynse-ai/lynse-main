import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

class AppBarWidgets {
  AppBarWidgets._();

  static AppBar getAppBar({
    String title = "",
    showBackButton = true,
    Callback? gobackOntap,
    TextAlign textAlign = TextAlign.left,
    List<Widget>? actions,
    Color backgroundColor = Colors.white,
  }) {
    return AppBar(
      actionsPadding: EdgeInsets.only(right: 16.w),
      elevation: 0,
      titleSpacing: 0,
      title: Container(
        child:
            title.isNotEmpty
                ? Text(
                  title.tr,
                  textAlign: textAlign,
                  style: TextStyle(
                    color: ColorUtil.fromHexString("#333333"),
                    fontWeight: FontWeight.w500,
                    fontSize: 16.w,
                    height: 24 / 16,
                  ),
                )
                : null,
      ),
      centerTitle: textAlign == TextAlign.left ? false : true,
      leading: Container(
        padding: EdgeInsets.only(left: 12.w, right: 18.w),
        child: GestureDetector(
          onTap:
              gobackOntap ??
              () {
                NavigationUtils.back();
              },
          child: Image.asset(
            'assets/images_v3/back.png',
            width: 20.w,
            height: 20.w,
          ),
        ),
      ),
      backgroundColor: backgroundColor,

      actions: actions,
    );
  }

  static AppBar getAppBarWithSearch({
    showBackButton = true,
    Callback? gobackOntap,
    required Widget title,
  }) {
    return AppBar(
      elevation: 0,
      actionsPadding: EdgeInsets.only(right: 12.w),
      titleSpacing: 0,
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      title: title,
      leading: Container(
        padding: EdgeInsets.only(left: 12.w, right: 18.w),
        child: GestureDetector(
          onTap:
              gobackOntap ??
              () {
                NavigationUtils.back();
              },
          child: Image.asset(
            'assets/images_v3/back.png',
            width: 20.w,
            height: 20.w,
          ),
        ),
      ),
      actions: [SizedBox(width: 12.w)],
    );
  }
}

import 'package:dting/utils/color_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

class RequestDataWidget extends GetView {
  RequestDataWidget({super.key, required this.ontap, this.tipText});
  Callback ontap;
  String? tipText;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/homeindex/nodata.png',
            height: 200.w,
            width: 200.w,
            // color: Colors.grey,
          ),
          SizedBox(height: 10.w),
          tipText == null || tipText == ""
              ? GestureDetector(
                onTap: ontap,
                child: Container(
                  width: 114.w,
                  height: 35.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.w),
                    gradient: LinearGradient(
                      colors: [
                        ColorUtil.fromHexString("#B886FF"),
                        ColorUtil.fromHexString("#7352DD", 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "goto".tr,
                        style: TextStyle(
                          color: ColorUtil.fromHexString("#FFFFFF"),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.w,
                          height: 22 / 12,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      SvgPicture.asset(
                        'assets/svg/device/goto.svg',
                        height: 16.w,
                        width: 16.w,
                      ),
                    ],
                  ),
                ),
              )
              : Text(
                tipText!.tr,
                style: TextStyle(
                  color: ColorUtil.fromHexString("#7E8492"),
                  fontWeight: FontWeight.w500,
                  fontSize: 12.w,
                  height: 14.06 / 12,
                ),
              ),
          SizedBox(height: 30.w),
        ],
      ),
    );
  }
}

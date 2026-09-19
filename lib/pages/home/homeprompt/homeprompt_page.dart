import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; 
import 'package:get/get.dart';

import 'package:dting/utils/color_util.dart'; 
import 'homeprompt_controller.dart';

class HomePromptPage extends GetView<HomePromptController> {
  const HomePromptPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: ColorUtil.fromHexString("#FFFFFF"),
      appBar: AppBarWidgets.getAppBar(
        actions: [
          GestureDetector(
            onTap: () {
              NavigationUtils.toHomeIndex();
            },
            child: Text(
              "skip".tr,
              style: TextStyle(
                color: ColorUtil.fromHexString("#161616"),
                fontWeight: FontWeight.w500,
                fontSize: 16.w,
                height: 24 / 16,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        padding: EdgeInsets.only(left: 24.w, right: 24.w, bottom: 50.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _contentTip(),
            BottomBarWidget(
              title: "Start connecting device",
              lineheigt: 22,
              ontap: () {
                NavigationUtils.toBootstrapOperation();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentTip() {
    return Container(
      padding: EdgeInsets.only(top: 30.w, left: 12.w, right: 12.w),
      decoration: BoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 120.w,
            width: 327.w,
            alignment: Alignment.center,
            child: RichText(
              textAlign: TextAlign.center,
              overflow: TextOverflow.clip,
              softWrap: true,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "${'We invite you to experience the'.tr} ",
                    style: TextStyle(
                      fontFamily: "Fugaz One",
                      color: ColorUtil.fromHexString("#161616"),
                      fontWeight: FontWeight.w400,
                      fontSize: 24.w,
                      height: 28 / 24,
                    ),
                  ),
                  TextSpan(
                    text: "${"Dting AI".tr} ",
                    style: TextStyle(
                      fontFamily: "Fugaz One",
                      color: ColorUtil.fromHexString("#7857ED"),
                      fontWeight: FontWeight.w400,
                      fontSize: 24.w,
                      height: 28 / 24,
                    ),
                  ),
                  TextSpan(
                    text: "Voice Recorder".tr,
                    style: TextStyle(
                      fontFamily: "Fugaz One",
                      color: ColorUtil.fromHexString("#161616"),
                      fontWeight: FontWeight.w400,
                      fontSize: 24.w,
                      height: 28 / 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            "where artificial intelligence and audio converge to usher in a new era. This innovative tool accurately captures every moment of inspiration and brings it vividly to life through sound."
                .tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ColorUtil.fromHexString("#5B5E68"),
              fontWeight: FontWeight.w400,
              fontSize: 14.w,
              height: 16 / 14,
            ),
          ),
          SizedBox(height: 30.w),
           Image.asset(
            'assets/images/homeindex/device.png',
            height: 200.w,
            width: 200.w,
          ),
        ],
      ),
    );
  }
}

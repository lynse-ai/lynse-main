import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

class AnimationGetData extends GetView {
  const AnimationGetData({
    super.key,
    required this.title,
    this.assnameSize = 40,
    required this.info,
  });
  final String title;
  final String info;
  final double assnameSize;
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          bottom: -20,
          child: Lottie.asset(
            'assets/lotties/voiceDetail.lottie',
            width: Get.width,
            fit: BoxFit.fitWidth,
          ),
        ),
        Container(
          width: Get.width,
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 30.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(title.tr).mainTitle(fontSize: 18),
              Text(info.tr).descText(
                textAlign: TextAlign.center,
                color: ColorUtil.fromHexString("#858C9B"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
 
import 'hometip_controller.dart';

class HomeTipPage extends GetView<HomeTipController> {
  const HomeTipPage({super.key});

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
      height: 430.w,
      width: 327.w,
      decoration: BoxDecoration(),
      child:  SvgPicture.asset(
        'assets/svg/tip.svg',
        height: 430.w,
        width: 327.w,
      ),
    );
  }
}

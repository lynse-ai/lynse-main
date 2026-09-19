import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

import 'help_controller.dart';

class HelpAndFeedBackPage extends GetView<HelpAndFeedBackController> {
  const HelpAndFeedBackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidgets.getAppBar(
        title: "feedback".tr,
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      ),
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      body: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.only(left: 24.w, right: 24.w, top: 30.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.only(left: 11.w, right: 11.w),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: ColorUtil.fromHexString("#FFFFFF"),
                borderRadius: BorderRadius.circular(10.w),
              ),
              child: Column(
                children: [
                  _copyPhone(),

                  DividerWidget(spacer: 0),
                  _copyFeedback(),

                  DividerWidget(spacer: 0),
                  _textAndRightBack(
                    ontap: () {
                      NavigationUtils.toReport();
                    },
                    title: 'help'.tr,
                  ),
                ],
              ),
            ),
            // _hotIssues(),
            // SizedBox(height: 20.w),
            // Container(
            //   padding: EdgeInsets.only(left: 11.w, right: 11.w),
            //   decoration: BoxDecoration(
            //     color: ColorUtil.fromHexString("#FFFFFF"),
            //     borderRadius: BorderRadius.circular(10.w),
            //   ),
            //   child: _textAndRightBack(
            //     ontap: () {
            //       //TODO
            //     },
            //     title: 'Whole question'.tr,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _copyFeedback() {
    return GestureDetector(
      onLongPress: () {
        controller.callPhone();
      },
      onTap: () {
        controller.copyPhone();
      },
      child: Container(
        height: 50.w,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${"feedbackPhone".tr}：13632872577",
              style: TextStyle(
                color: ColorUtil.fromHexString("#1E1E1E"),
                fontWeight: FontWeight.w400,
                fontSize: 16.w,
                height: 24 / 16,
              ),
            ),
            Container(
              padding: EdgeInsets.only(left: 10.w),
              child: Image.asset(
                "assets/images_v3/copy2.png",
                width: 24.w,
                height: 24.w,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _copyPhone() {
    return GestureDetector(
      onLongPress: () {
        controller.callPhone();
      },
      onTap: () {
        controller.copyPhone();
      },
      child: Container(
        height: 50.w,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${"phone".tr}：13632872577",
              style: TextStyle(
                color: ColorUtil.fromHexString("#1E1E1E"),
                fontWeight: FontWeight.w400,
                fontSize: 16.w,
                height: 24 / 16,
              ),
            ),
            Container(
              padding: EdgeInsets.only(left: 10.w),
              child: Image.asset(
                "assets/images_v3/copy2.png",
                width: 24.w,
                height: 24.w,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hotIssues() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Hot issue".tr,
          style: TextStyle(
            color: ColorUtil.fromHexString("#1E1E1E"),
            fontWeight: FontWeight.w600,
            fontSize: 18.w,
            height: 21.09 / 18,
          ),
        ),
        SizedBox(height: 20.w),
        Container(
          padding: EdgeInsets.only(left: 11.w, right: 11.w),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: ColorUtil.fromHexString("#FFFFFF"),
            borderRadius: BorderRadius.circular(10.w),
          ),
          child: Column(
            children: [
              _textAndRightBack(
                ontap: () {
                  //TODO
                },
                title: "${'Hot issue'.tr}-1",
              ),
              Divider(height: 1.w, color: ColorUtil.fromHexString("#EBECF0")),
              _textAndRightBack(
                ontap: () {
                  //TODO
                },
                title: '${'Hot issue'.tr}-2',
              ),
              Divider(height: 1.w, color: ColorUtil.fromHexString("#EBECF0")),
              _textAndRightBack(
                ontap: () {
                  //TODO
                },
                title: '${'Hot issue'.tr}-3',
              ),
              Divider(height: 1.w, color: ColorUtil.fromHexString("#EBECF0")),
              _textAndRightBack(
                ontap: () {
                  //TODO
                },
                title: '${'Hot issue'.tr}-4',
              ),
              Divider(height: 1.w, color: ColorUtil.fromHexString("#EBECF0")),
              _textAndRightBack(
                ontap: () {
                  //TODO
                },
                title: '${'Hot issue'.tr}-5',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _textAndRightBack({
    required Callback ontap,
    required String title,
    String assetsName = 'assets/images_v3/arrow-right.png',
    Color? assetsColor,
  }) {
    return GestureDetector(
      onTap: ontap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 50.w,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: ColorUtil.fromHexString("#1E1E1E"),
                fontWeight: FontWeight.w400,
                fontSize: 16.w,
                height: 24 / 16,
              ),
            ),
            Container(
              padding: EdgeInsets.only(left: 10.w),
              child: Image.asset(
                assetsName,
                width: 24.w,
                height: 24.w,
                color: assetsColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:dting/model/personal_model/submit_report_model.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'report_controller.dart';

class ReportPage extends GetView<ReportController> {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBarWidgets.getAppBar(
        title: "feedback".tr,
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      ),
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      body: Container(
        padding: EdgeInsets.only(
          left: 24.w,
          right: 24.w,
          top: 11.w,
          bottom: 54.w,
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _textQuestion(),
                    SizedBox(height: 15.w),
                    _reportImage(),
                    SizedBox(height: 15.w),
                    reportPhone(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20.w),
            BottomBarWidget(
              title: "submit",
              ontap: () {
                controller.uploadReport();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget reportPhone() {
    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        color: Colors.white,
      ),
      width: Get.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("phoneOrEmail".tr).descText(fontSize: 15),
          SizedBox(height: 8.w),
          TextField(
            controller: controller.reportPhoneController,
            cursorColor: ColorUtil.fromHexString('#1E1E1E'),
            style: TextStyle(
              color: ColorUtil.fromHexString('#1E1E1E'),
              fontSize: 14.w,
              height: 20 / 16,
            ),
            maxLines: 1,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              // 当用户点击完成按钮时收起键盘
              FocusManager.instance.primaryFocus?.unfocus();
            },
            decoration: InputDecoration(
              isDense: true,
              hintText: "hint".tr,
              hintStyle: TextStyle(
                color: ColorUtil.fromHexString("#5B5E68"),
                fontSize: 15.sp,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportImage() {
    return Obx(
      () => Container(
        padding: EdgeInsets.all(15.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          color: Colors.white,
        ),
        width: Get.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "uploadImage".tr,
            ).descText(fontSize: 15, color: ColorUtil.fromHexString("#5B5E68")),
            SizedBox(height: 8.w),
            Wrap(
              children: [
                Wrap(
                  children:
                      controller.imageList
                          .map((image) => _imageItem(image))
                          .toList(),
                ),
                _uploadImage(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageItem(SubmitReportModel image) {
    return Stack(
      children: [
        GestureDetector(
          onTap: controller.pickImage,
          child: Container(
            width: 92.w,
            height: 92.w,
            margin: EdgeInsets.only(right: 10.w, bottom: 10.w),
            decoration: BoxDecoration(
              color: ColorUtil.fromHexString("#000000", 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(image.mediaUrl!),
                fit: BoxFit.fitHeight,
                height: 92.w,
                // width: 92.w,
              ),
            ),
          ),
        ),

        Positioned(
          top: -15,
          right: -5,
          child: IconButton(
            icon: Image.asset(
              "assets/images_v3/clear.png",
              width: 12.w,
              height: 12.w,
            ),
            onPressed: () {
              controller.removeImage(image);
            },
            iconSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _uploadImage() {
    return GestureDetector(
      onTap: controller.pickImage,
      child: DottedBorder(
        options: RoundedRectDottedBorderOptions(
          dashPattern: [4, 4],
          strokeWidth: 1,
          radius: Radius.circular(16),
          color: ColorUtil.fromHexString("#999999"),
        ),
        child: Container(
          width: 90.w,
          height: 90.w,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r)),
          child: Center(
            child: Image.asset(
              "assets/images_v3/add.png",
              width: 24,
              height: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _textQuestion() {
    return Obx(
      () => Container(
        height: 226.w,
        width: Get.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          color: Colors.white,
        ),
        padding: EdgeInsets.all(15.w),
        child: Column(
          children: [
            Row(
              children: [
                Text("des".tr).descText(fontSize: 15),
                SizedBox(width: 5.w),
                Text("*").descText(fontSize: 15, color: Colors.red),
              ],
            ),
            SizedBox(height: 8.w),
            Expanded(
              child: TextField(
                controller: controller.reportTextController,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(30), // 限制输入 30 个字符
                ],
                cursorColor: ColorUtil.fromHexString('#1E1E1E'),
                style: TextStyle(
                  color: ColorUtil.fromHexString('#1E1E1E'),
                  fontSize: 14.w,
                  height: 20 / 16,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
                onChanged: (value) {
                  controller.textNumber.value = value.length;
                },
                onSubmitted: (_) {
                  // 当用户点击完成按钮时收起键盘
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                decoration: InputDecoration(
                  isDense: true,
                  hintText: "hint".tr,
                  hintStyle: TextStyle(
                    color: ColorUtil.fromHexString("#5B5E68"),
                    fontSize: 15.sp,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 0,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            SizedBox(height: 8.w),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text("${controller.textNumber.value}").descText(fontSize: 15),
                Text("/30").descText(
                  fontSize: 15,
                  color: ColorUtil.fromHexString("#5B5E68"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

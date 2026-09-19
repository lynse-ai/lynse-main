import 'package:dting/pages/login/widget/phone_input_widget.dart';
import 'package:dting/pages/login/widget/sendotp_widget.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:keyboard_dismisser/keyboard_dismisser.dart';

import 'bindmobilephone_controller.dart';

class BindMobilePhonePage extends GetView<BindMobilePhoneController> {
  const BindMobilePhonePage({super.key});

  @override
  Widget build(BuildContext context) {
    bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    return Obx(
      () => KeyboardDismisser(
        child: Stack(
          children: [
            // 背景图层（轮播图）
            AnimatedSwitcher(
              duration: Duration(seconds: 2),
              child: Image.asset(
                controller.images[controller.currentIndex.value],
                key: ValueKey(controller.images[controller.currentIndex.value]),
                width: Get.width,
                height: Get.height,
                fit: BoxFit.cover,
              ),
            ),

            AnimatedContainer(
              duration: Duration(milliseconds: 400),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      isKeyboardVisible
                          ? [
                            ColorUtil.fromHexString("#161616", 0.7),
                            ColorUtil.fromHexString("#161616"),
                          ]
                          : [
                            ColorUtil.fromHexString("#161616", 0),
                            ColorUtil.fromHexString("#161616"),
                          ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Container(
                width: Get.width,
                height: Get.height,
                padding: EdgeInsets.only(left: 31.w, right: 31.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("bindPhone".tr).boldTitle(
                      fontSize: 25,
                      color: ColorUtil.fromHexString("#FFFFFF"),
                    ),
                    Text("bindPhoneLogin".tr).descText(
                      fontSize: 13,
                      color: ColorUtil.fromHexString("#FFFFFF"),
                    ),

                    AnimatedPadding(
                      duration: Duration(milliseconds: 380),
                      padding: EdgeInsets.only(
                        top: isKeyboardVisible ? 60.w : 100.w,
                        bottom: isKeyboardVisible ? 40.w : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PhoneInputWidget(
                            controller: controller.bindPhoneController,
                            error: controller.checkBindPhone,
                            focusNode: controller.phoneFocusNode,
                          ),
                          SizedBox(height: 20.w),
                          SendOtpWidget(
                            hintText: "codeTip".tr,
                            codeController: controller.codeController,
                            phoneController: controller.bindPhoneController,
                            sendType: "BIND",
                            error: controller.checkBindCode,
                            phoneError: controller.checkBindPhone,
                            codeFocusNode: controller.codeFocusNode,
                            phoneFocusNode: controller.phoneFocusNode,
                          ),
                          SizedBox(height: 35.w),
                          BottomBarWidget(
                            title: "bindPhone",
                            height: 40.w,
                            color: ColorUtil.fromHexString("#7857ED", 0.8),
                            ontap: () {
                              controller.bindPhone();
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 110.w),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

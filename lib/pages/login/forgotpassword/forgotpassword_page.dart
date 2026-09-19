import 'package:dting/pages/login/widget/icon_inpit_widget.dart';
import 'package:dting/pages/login/widget/logo_widget.dart';
import 'package:dting/pages/login/widget/phone_input_widget.dart';
import 'package:dting/pages/login/widget/sendotp_widget.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
 
import 'forgotpassword_controller.dart';

class ForgotpasswordPage extends GetView<ForgotPasswordController> {
  const ForgotpasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: ColorUtil.fromHexString("#FFFFFF"),
      appBar: AppBarWidgets.getAppBar(title: "Forgot password"),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(left: 30.w, right: 30.w, top: 60.w),
          decoration: BoxDecoration(color: ColorUtil.fromHexString("#FFFFFF")),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  LogoWidget(),
                  SizedBox(height: 60.w),
                  _forgotPwdWidget(),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(left: 30.w, right: 30.w, bottom: 50.w),
        child: BottomBarWidget(
          title: "Definite modification".tr,
          lineheigt: 22,
          ontap: () {
            controller.definite();
          },
        ),
      ),
    );
  }

  Widget _forgotPwdWidget() {
    return Column(
      children: [
        SizedBox(height: 20.w),
        PhoneInputWidget(
          controller: controller.forgotPhoneController,
          error: controller.checkPhone,
        ),
        SizedBox(height: 20.w),
        SendOtpWidget(
          hintText: "Your OTP".tr,
          codeController: controller.codeController,
          phoneController: controller.forgotPhoneController,
          sendType: "RESET",
          error: controller.checkCode,
          phoneError: controller.checkPhone,
        ),
        SizedBox(height: 20.w),
        IconInputWidget(
          controller: controller.forgotPwdController,
          keyboardType: TextInputType.visiblePassword,
          error: controller.checkPwd,
          hintText: "Enter password".tr,
        ),
        SizedBox(height: 20.w),
        IconInputWidget(
          hintText: "Confirm password".tr,
          controller: controller.forgotConfirmPwdController,
          error: controller.checkRePwd,
          keyboardType: TextInputType.visiblePassword,
        ),
      ],
    );
  }
}

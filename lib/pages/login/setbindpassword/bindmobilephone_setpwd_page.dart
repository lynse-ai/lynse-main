import 'package:dting/pages/login/setbindpassword/bindmobilephone_setpwd_controller.dart';
import 'package:dting/pages/login/widget/icon_inpit_widget.dart';
import 'package:dting/pages/login/widget/logo_widget.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class SetPwdForBindMobilePhonePage
    extends GetView<SetPwdForBindMobilePhoneController> {
  const SetPwdForBindMobilePhonePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: ColorUtil.fromHexString("#FFFFFF"),
      appBar: AppBarWidgets.getAppBar(title: "bindPhone"),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(left: 30.w, right: 30.w, top: 60.w),
          decoration: BoxDecoration(color: ColorUtil.fromHexString("#FFFFFF")),
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    LogoWidget(),
                    SizedBox(height: 60.w),
                    _bindMobilePhoneWidget(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(left: 30.w, right: 30.w, bottom: 50.w),
        child: BottomBarWidget(
          title: "confirm",
          lineheigt: 22,
          ontap: () {
            controller.setPwd();
          },
        ),
      ),
    );
  }

  Widget _bindMobilePhoneWidget() {
    return Column(
      children: [
        SizedBox(height: 20.w),
        IconInputWidget(
          controller: controller.bindPhoneSetPwdController,
          keyboardType: TextInputType.visiblePassword,
          error: controller.checkBindBySetPwd,
          hintText: "inputPwd".tr,
        ),
        SizedBox(height: 20.w),
        IconInputWidget(
          hintText: "confirmPwd".tr,
          controller: controller.bindPhoneConfirmPwdController,
          error: controller.checkBindBySetRePwd,
          keyboardType: TextInputType.visiblePassword,
        ),
      ],
    );
  }
}

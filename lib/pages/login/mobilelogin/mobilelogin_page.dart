import 'package:dting/pages/login/widget/phone_input_widget.dart';
import 'package:dting/pages/login/widget/sendotp_widget.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/utils/permission_helper.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:keyboard_dismisser/keyboard_dismisser.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'mobilelogin_controller.dart';

class MobileLogInPage extends GetView<MobileLogInController> {
  const MobileLogInPage({super.key});

  @override
  Widget build(BuildContext context) {
    bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    return Obx(
      () => PopScope(
        canPop: false, // 拦截返回
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            SystemChannels.platform.invokeMethod('SystemNavigator.pop');
          }
        },
        child: Stack(
          children: [
            KeyboardDismisser(
              child: Stack(
                children: [
                  // 背景图层（轮播图）
                  AnimatedSwitcher(
                    duration: Duration(seconds: 2),
                    child: Image.asset(
                      controller.images[controller.currentIndex.value],
                      key: ValueKey(
                        controller.images[controller.currentIndex.value],
                      ),
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
                      padding: EdgeInsets.only(
                        left: 31.w,
                        right: 31.w,
                        bottom: 60.w,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("phoneLogin".tr).boldTitle(
                            fontSize: 25,
                            color: ColorUtil.fromHexString("#FFFFFF"),
                          ),
                          Text("register".tr).descText(
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
                                  controller: controller.phoneController,
                                  error: controller.checkPhone,
                                  focusNode: controller.phoneFocusNode,
                                ),
                                SizedBox(height: 20.w),
                                SendOtpWidget(
                                  hintText: "codeTip".tr,
                                  codeController: controller.codeController,
                                  phoneController: controller.phoneController,
                                  sendType: "LOGIN",
                                  error: controller.checkCode,
                                  phoneError: controller.checkPhone,
                                  codeFocusNode: controller.codeFocusNode,
                                  phoneFocusNode: controller.phoneFocusNode,
                                ),
                                SizedBox(height: 35.w),
                                BottomBarWidget(
                                  title: "Login",
                                  height: 40.w,
                                  color: ColorUtil.fromHexString(
                                    "#7857ED",
                                    0.8,
                                  ),
                                  ontap: () {
                                    controller.login();
                                  },
                                ),
                                _agreeBox(),
                              ],
                            ),
                          ),
                          SizedBox(height: 110.w),

                          _segmentation(),
                          Container(
                            padding: EdgeInsets.only(top: 12.w),

                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                controller.wxInstalled ?
                                GestureDetector(
                                  child: Image.asset(
                                    "assets/images_v3/wechat2.png",
                                    width: 40.w,
                                  ),
                                  onTap: () {
                                    controller.wexinRequest();
                                  },
                                ): SizedBox.shrink(),
                                controller.wxInstalled ? SizedBox(width: 30.w) : SizedBox.shrink(),
                                GestureDetector(
                                  child: Image.asset(
                                    "assets/images_v3/apple2.png",
                                    width: 40.w,
                                  ),
                                  onTap: () {
                                    if (PermissionsHelper.isIOS()) {
                                      controller.appleLogin();
                                    } else {
                                      DialogHelper.showToastDialog("useIphone");
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            controller.showAgreeDialog.value ? _showArgeeDialog() : SizedBox(),
          ],
        ),
      ),
    );
  }

  Widget _segmentation() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.w),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1.w,
              width: Get.width,
              color: ColorUtil.fromHexString("#7E8492"),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            "thirdParty".tr,
          ).descText(color: ColorUtil.fromHexString("#B2B6BF")),
          SizedBox(width: 8.w),

          Expanded(
            child: Container(
              height: 1.w,
              width: Get.width,
              color: ColorUtil.fromHexString("#7E8492"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _showArgeeDialog() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: Get.height,
          width: Get.width,
          decoration: BoxDecoration(
            color: ColorUtil.fromHexString("#161616", 0.8),
          ),
        ),
        Container(
          width: Get.width,
          margin: EdgeInsets.symmetric(horizontal: 32.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.w),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.only(left: 24.w, right: 24.w, top: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("AgreementPrivacy".tr).boldTitle(fontSize: 20),
                      ],
                    ),
                    SizedBox(height: 15.w),
                    Text("thanks".tr).descText(
                      fontSize: 16.w,
                      color: ColorUtil.fromHexString("#B2B6BF"),
                    ),
                    RichText(
                      textAlign: TextAlign.start,
                      overflow: TextOverflow.clip,
                      softWrap: true,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "    ${"AgreementTip".tr}《",
                            style: TextStyle(
                              fontFamily: "Fugaz One",
                              color: ColorUtil.fromHexString("#B2B6BF"),
                              fontWeight: FontWeight.w400,
                              fontSize: 16.w,
                              height: 1.5,
                            ),
                          ),
                          TextSpan(
                            text: "User Agreement".tr,
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      Get.context!,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => WebViewPage(
                                              title: "User Agreement".tr,
                                              url:
                                                  'https://dting.geekdanceshop.com/privacy.html',
                                            ),
                                      ),
                                    );
                                  },
                            style: TextStyle(
                              fontFamily: "Fugaz One",
                              color: ColorUtil.fromHexString("#7857ED"),
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w400,
                              fontSize: 16.w,
                              height: 1.5,
                            ),
                          ),
                          TextSpan(
                            text: "》${"and".tr}《".tr,
                            style: TextStyle(
                              fontFamily: "Fugaz One",
                              color: ColorUtil.fromHexString("#B2B6BF"),
                              fontWeight: FontWeight.w400,
                              fontSize: 16.w,
                              height: 1.5,
                            ),
                          ),
                          TextSpan(
                            text: "Privacy Policy".tr,
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      Get.context!,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => WebViewPage(
                                              title: "Privacy Policy".tr,
                                              url:
                                                  'https://dting.geekdanceshop.com/useragreement.html',
                                            ),
                                      ),
                                    );
                                  },
                            style: TextStyle(
                              fontFamily: "Fugaz One",
                              color: ColorUtil.fromHexString("#7857ED"),
                              fontWeight: FontWeight.w400,
                              decoration: TextDecoration.underline,
                              fontSize: 16.w,
                              height: 1.5,
                            ),
                          ),
                          TextSpan(
                            text: "》${"AgreementTip2".tr}",
                            style: TextStyle(
                              fontFamily: "Fugaz One",
                              color: ColorUtil.fromHexString("#B2B6BF"),
                              fontWeight: FontWeight.w400,
                              fontSize: 16.w,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.w),
              DividerWidget(spacer: 0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        LocalDataBase().basicBox!.put("agree", false);
                        // controller.agree.value = false;
                        controller.showAgreeDialog.value = false;
                      },
                      child: Container(
                        width: Get.width,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          "disagree".tr,
                          style: TextStyle(
                            color: ColorUtil.fromHexString("#B2B6BF"),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1.w,
                    height: 40.w,
                    color: ColorUtil.fromHexString("#E5E6EB"),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        LocalDataBase().basicBox!.put("agree", true);
                        // controller.agree.value = true;
                        controller.showAgreeDialog.value = false;
                      },
                      child: Container(
                        width: Get.width,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                          color: Colors.white,
                        ),
                        height: 40.w,
                        alignment: Alignment.center,
                        child: Text(
                          "agree".tr,
                          style: TextStyle(
                            color: ColorUtil.fromHexString("#7857ED"),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _agreeBox() {
    return Obx(
      () => Container(
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        margin: EdgeInsets.symmetric(vertical: 5.w),
        child: RichText(
          textAlign: TextAlign.center,
          overflow: TextOverflow.clip,
          text: TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: () {
                    controller.agree.value = !controller.agree.value;
                    if (controller.agree.value) {
                      LocalDataBase().basicBox!.put("agree", true);
                    } else {
                      LocalDataBase().basicBox!.put("agree", false);
                    }
                  },
                  child: Container(
                    width: 30.w,
                    height: 30.w,
                    padding: EdgeInsets.only(right: 2.w),
                    child: Center(
                      child: Image.asset(
                        controller.agree.value
                            ? 'assets/images_v3/agree.png'
                            : 'assets/images_v3/notagree.png',
                        width: 20.w,
                        height: 20.w,
                      ),
                    ),
                  ),
                ),
              ),
              TextSpan(
                text: 'agreeTip'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: ColorUtil.fromHexString('#B2B6BF'),
                  fontSize: 12.w,
                  height: 24 / 12,
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
              TextSpan(
                text: ' 《'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: ColorUtil.fromHexString('#FFFFFF'),
                  fontSize: 12.w,
                  height: 24 / 12,
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: () {
                    // NavigationUtils.toAgreement(
                    //   text: controller.userAgrssmentText,
                    //   title: "User Agreement".tr,
                    // );
                    Navigator.push(
                      Get.context!,
                      MaterialPageRoute(
                        builder:
                            (_) => WebViewPage(
                              title: "User Agreement".tr,
                              url:
                                  'https://dting.geekdanceshop.com/useragreement.html',
                            ),
                      ),
                    );
                  },
                  child: Text("User Agreement".tr).boldTitle(
                    color: ColorUtil.fromHexString('#FFFFFF'),
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: ColorUtil.fromHexString('#FFFFFF'),
                  ),
                ),
              ),
              TextSpan(
                text: '》'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: ColorUtil.fromHexString('#FFFFFF'),
                  fontSize: 12.w,
                  height: 24 / 12,
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
              TextSpan(
                text: ' ${"and".tr} ',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: ColorUtil.fromHexString('#B2B6BF'),
                  fontSize: 12.w,
                  height: 24 / 12,
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
              TextSpan(
                text: '《',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: ColorUtil.fromHexString('#FFFFFF'),
                  fontSize: 12.w,
                  height: 24 / 12,
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: () {
                    // NavigationUtils.toAgreement(
                    //   text: controller.privacyPolicyText,
                    //   title: "Privacy Policy".tr,
                    // );
                    Navigator.push(
                      Get.context!,
                      MaterialPageRoute(
                        builder:
                            (_) => WebViewPage(
                              title: "Privacy Policy".tr,
                              url:
                                  'https://dting.geekdanceshop.com/privacy.html',
                            ),
                      ),
                    );
                  },
                  child: Text("Privacy Policy".tr).boldTitle(
                    color: ColorUtil.fromHexString('#FFFFFF'),
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: ColorUtil.fromHexString('#FFFFFF'),
                  ),
                ),
              ),
              TextSpan(
                text: '》',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: ColorUtil.fromHexString('#FFFFFF'),
                  fontSize: 12.w,
                  height: 24 / 12,
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const WebViewPage({super.key, required this.url, required this.title});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBarWidgets.getAppBar(
        title: widget.title.tr,
        textAlign: TextAlign.center,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

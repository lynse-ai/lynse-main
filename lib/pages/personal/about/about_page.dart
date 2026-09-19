import 'package:dting/pages/login/mobilelogin/mobilelogin_page.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'about_controller.dart';

class AboutPage extends GetView<AboutController> {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidgets.getAppBar(
        title: "AboutDting".tr,
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      ),
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      body: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.only(
          left: 24.w,
          right: 24.w,
          top: 30.w,
          bottom: 34.w,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _logo(),
            SizedBox(height: 20.w),
            Text("${"dting".tr} ").boldTitle(fontSize: 20),
            SizedBox(height: 2.w),
            Obx(
              () => Text("V.${controller.versionString}").descText(
                fontSize: 20,
                color: ColorUtil.fromHexString("#7E8492"),
              ),
            ),
            SizedBox(height: 25.w),
            Container(
              padding: EdgeInsets.only(left: 11.w, right: 11.w),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: ColorUtil.fromHexString("#FFFFFF"),
                borderRadius: BorderRadius.circular(10.w),
              ),
              child: Column(
                children: [
                  _contentWidget(
                    title: "User Agreement",
                    ontap: () {
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
                  ),
                  DividerWidget(spacer: 0),
                  _contentWidget(
                    title: "Privacy Policy",
                    ontap: () {
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
                  ),
                ],
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
              child: _contentWidget(
                title: "updateVersion",
                ontap: () {
                  //
                },
              ),
            ),
            Spacer(),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  Get.context!,
                  MaterialPageRoute(
                    builder:
                        (_) => WebViewPage(
                          title: "icp".tr,
                          url:
                              'https://beian.miit.gov.cn/publish/query/indexFirst.action',
                        ),
                  ),
                );
              },
              child: Text("${"icp2".tr}：粤ICP备2025424446号").descText(
                fontSize: 12,
                color: ColorUtil.fromHexString("#000000", 0.7),
              ),
            ),
            SizedBox(height: 5.w),
            Text("company".tr).descText(
              fontSize: 12,
              color: ColorUtil.fromHexString("#000000", 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentWidget({required String title, required VoidCallback ontap}) {
    return Container(
      height: 50.w,
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: ontap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title.tr).descText(),
            Container(
              padding: EdgeInsets.only(left: 10.w),
              child: Image.asset(
                'assets/images_v3/arrow-right.png',
                width: 24.w,
                height: 24.w,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logo() {
    return Container(
      height: 147.w,
      width: 147.w,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // color: ColorUtil.fromHexString("#FFFFFF"),
        borderRadius: BorderRadius.circular(30.w),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 0),
            blurRadius: 24,
            spreadRadius: 0,
            color: ColorUtil.fromHexString("#150239", 0.12),
          ),
          BoxShadow(
            offset: Offset(1, 1),
            blurRadius: 2,
            spreadRadius: 0,
            color: ColorUtil.fromHexString("#F0E7FF"),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images_v3/desktop1.png',
        height: 147.w,
        width: 147.w,
      ),
    );
  }
}

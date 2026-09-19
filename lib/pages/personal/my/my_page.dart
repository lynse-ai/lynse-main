import 'dart:io';

import 'package:dting/pages/personal/my/my_controller.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/image_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

class MyPage extends GetView<MyController> {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 拦截返回
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await Future.delayed(const Duration(milliseconds: 200));
          // 使用现有的NvEasyPlugin最小化应用
          //这里需要判断是否是Android
          if (Platform.isAndroid) {
            await NvEasyPlugin().minimizeApp();
          }
        }
      },
      child: SafeArea(
        top: false,
        child: Obx(
          () => Container(
            padding: EdgeInsets.only(left: 24.w, right: 24.w, top: 55.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _profilePicture(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 20.w),
                        _purchasePoints(),
                        SizedBox(height: 20.w),
                        _content(),
                        SizedBox(height: 20.w),
                        _aboutContent(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //剩余积分卡片
  Widget _purchasePoints() {
    return Container(
      width: Get.width,
      padding: EdgeInsets.symmetric(vertical: 15.w, horizontal: 14.w),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.w),
        gradient: LinearGradient(
          colors: [
            ColorUtil.fromHexString("#DDEBFF"),
            ColorUtil.fromHexString("#ECC6FF"),
            ColorUtil.fromHexString("#8968EF"),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.40, 0.80],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text("${"PointsLeft".tr}：").mainTitle(
                            color: ColorUtil.fromHexString("#7857ED"),
                            fontSize: 17,
                            maxLine: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "${controller.appController.userInfo.value.remainPointsAmountInt}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20.sp,
                              color: ColorUtil.fromHexString("#5D18C3"),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        NavigationUtils.toPurchasePoints();
                      },
                      child: Container(
                        height: 29.w,
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ColorUtil.fromHexString("#1E2D46"),
                              ColorUtil.fromHexString("#48365B"),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ShaderMask(
                          shaderCallback:
                              (bounds) => LinearGradient(
                                colors: [
                                  ColorUtil.fromHexString("#816EE4"),
                                  ColorUtil.fromHexString("#FF94F4"),
                                ],
                              ).createShader(
                                Rect.fromLTWH(
                                  0,
                                  0,
                                  bounds.width,
                                  bounds.height,
                                ),
                              ),
                          blendMode: BlendMode.srcIn,
                          child: Text('payPoint'.tr).mainTitle(fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),

                GestureDetector(
                  onTap: () async {
                    controller.showTransPointBott();
                  },
                  child: Container(
                    width: Get.width * 0.5,
                    padding: EdgeInsets.only(bottom: 12.w),
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        Text("transPoint".tr).descText(
                          fontSize: 11,
                          color: ColorUtil.fromHexString("#7857ED"),
                        ),
                        Image.asset(
                          'assets/images_v3/arrow-right.png',
                          width: 13.w,
                          height: 13.w,
                          color: ColorUtil.fromHexString("#7857ED"),
                        ),
                      ],
                    ),
                  ),
                ),

                LinearProgressIndicator(
                  value:
                      controller
                          .appController
                          .userInfo
                          .value
                          .percentPointsAmountDouble,
                  backgroundColor: ColorUtil.fromHexString("#D9E4FF"),
                  borderRadius: BorderRadius.circular(100.r),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ColorUtil.fromHexString("#7857ED"),
                  ),
                ),
                SizedBox(height: 8.w),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      " ${"points used".tr}：${controller.appController.userInfo.value.usedPointsAmountInt}",
                    ).descText(
                      color: ColorUtil.fromHexString("#5D18C3"),
                      fontSize: 10,
                    ),
                    Text(
                      "${"points total".tr}：${controller.appController.userInfo.value.pointsAmountInt} ",
                    ).descText(
                      color: ColorUtil.fromHexString("#5D18C3"),
                      fontSize: 10,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
        ],
      ),
    );
  }

  //关于谛听
  Widget _aboutContent() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.w),
        color: ColorUtil.fromHexString("#FFFFFF"),
      ),
      child: Column(
        children: [
          _menuCard(
            title: "AboutDting".tr,
            svgUrl: "assets/images_v3/icon_my_page_about.png",
            ontap: () {
              NavigationUtils.toHAbout();
            },
          ),
        ],
      ),
    );
  }

  //设备管理、文件下载、回收站、积分记录等功能内容
  Widget _content() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.w),
        color: ColorUtil.fromHexString("#FFFFFF"),
      ),
      child: Column(
        children: [
          _menuCard(
            title: "DeviceManagement".tr,
            svgUrl: "assets/images_v3/icon_my_page_device_manage.png",
            ontap: () {
              NavigationUtils.toConnectDevice();
            },
          ),
          Divider(color: ColorUtil.fromHexString("#EBECF0"), height: 1.w),
          _menuCard(
            title: "DownloadFile".tr,
            svgUrl: "assets/images_v3/icon_my_page_download.png",
            ontap: () {
              NavigationUtils.toDownloadFolder();
            },
          ),
          Divider(color: ColorUtil.fromHexString("#EBECF0"), height: 1.w),
          _menuCard(
            title: "RecycleBin".tr,
            svgUrl: "assets/images_v3/icon_my_page_recycle.png",

            ontap: () {
              NavigationUtils.toRecycleBin();
            },
          ),
          Divider(color: ColorUtil.fromHexString("#EBECF0"), height: 1.w),
          _menuCard(
            title: "PointsRecord".tr,
            svgUrl: "assets/images_v3/icon_my_page_point.png",
            ontap: () {
              NavigationUtils.toPointHistory();
            },
          ),
          Divider(color: ColorUtil.fromHexString("#EBECF0"), height: 1.w),
          _menuCard(
            title: "language".tr,
            svgUrl: "assets/images_v3/icon_my_page_language.png",
            ontap: () {
              NavigationUtils.toLanguagePage();
            },
          ),
          Divider(color: ColorUtil.fromHexString("#EBECF0"), height: 1.w),
          _menuCard(
            title: "feedback".tr,
            svgUrl: "assets/images_v3/icon_my_page_help.png",
            ontap: () {
              NavigationUtils.toHelpAndFeedBack();
            },
          ),
        ],
      ),
    );
  }

  //用户信息
  Widget _profilePicture() {
    return Obx(
      () => GestureDetector(
        onTap: () {
          NavigationUtils.toUser();
        },
        child: Container(
          color: Colors.transparent,
          width: Get.width,
          child: Row(
            children: [
              ImageNetwork(
                url: controller.appController.userInfo.value.avatarUrl,
                size: 40,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  controller.appController.userInfo.value.nickname ?? "--",
                ).boldTitle(
                  fontSize: 16,
                  maxLine: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 12.w),
              Image.asset(
                'assets/images_v3/arrow-right.png',
                width: 24.w,
                height: 24.w,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuCard({
    String title = "",
    String svgUrl = "assets/images_v3/icon_my_page_device_manage.png",
    required Callback ontap,
  }) {
    return GestureDetector(
      onTap: ontap,
      child: Container(
        height: 60.w,
        width: Get.width,
        color: ColorUtil.fromHexString("#FFFFFF"),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 图标（24x24）
            Row(
              children: [
                Image.asset(
                  svgUrl, // 替换为你的图标路径
                  width: 24.w,
                  height: 24.w,
                  fit: BoxFit.cover,
                ),
                SizedBox(width: 15.w), // 图标与文字之间的间距
                Text(title).descText(color: ColorUtil.fromHexString("#1E1E1E")),
              ],
            ),
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
}

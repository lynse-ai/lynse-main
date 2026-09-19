import 'package:dting/pages/home/home_index/home_file.dart';
import 'package:dting/pages/team/team_index/team_file_page.dart';
import 'package:dting/pages/personal/my/my_page.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/Icon_gestureDetector.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

import 'homeindex_controller.dart';

class HomeIndexPage extends GetView<HomeIndexController> {
  const HomeIndexPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Stack(
        children: [
          Scaffold(
            extendBody: true,
            backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
            bottomNavigationBar:
                controller.isMoreSelect.value
                    ? null
                    : _buildBottomNavigationMenu(),
            body: SafeArea(
              top: false,
              bottom: false,
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(), // 禁止滚动和动画
                controller: controller.tabController,
                children: [HomeFilePage(), TeamFilePage(), MyPage()],
              ),
            ),
          ),
          controller.isReceive.value == 0
              ? _fistLoginPoint()
              : SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _fistLoginPoint() {
    return Stack(
      alignment: AlignmentDirectional.center,
      children: [
        Container(
          width: Get.width,
          height: Get.height,
          color: ColorUtil.fromHexString("#161616", 0.3),
          alignment: Alignment.center,
          child: Container(
            width: 280.w,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/assets/vip.png', width: 54.w),
                SizedBox(height: 10.w),
                Text("pointBenefits".tr).boldTitle(fontSize: 18),
                SizedBox(height: 10.w),
                Text("+300 ${"points".tr}").boldTitle(
                  fontSize: 20,
                  color: ColorUtil.fromHexString("#14CB1A"),
                ),
                SizedBox(height: 10.w),
                Text("pointBenefitsTip2".tr).descText(fontSize: 13),
                SizedBox(height: 20.w),

                BottomBarWidget(
                  title: "Receive2".tr,
                  ontap: () {
                    controller.bonusReceivePoint();
                  },
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 200.w,
          left: 330.w,
          child: IconGesturedetector(
            assectName: 'assets/assets/clear2.png',
            ontap: () {
              controller.isReceive.value = 1;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationMenu() {
    return Container(
      height: 77.w,
      padding: EdgeInsets.only(left: 10.w, right: 10.w, bottom: 0),
      decoration: BoxDecoration(
        color: ColorUtil.fromHexString("#FFFFFF"),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, -2),
            blurRadius: 26,
            spreadRadius: 0,
            color: ColorUtil.fromHexString("#160051", 0.16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navigationMenuItem(
                title: "Files",
                assetsName: 'assets/assets/bottom-psonal.png',
                selectAssetsName: 'assets/assets/select-psonal.png',
                index: 0,
                ontap: () {},
              ),

              _navigationMenuItem(
                title: "Personal",
                assetsName: 'assets/assets/my.png',
                selectAssetsName: 'assets/assets/Frame.png',
                index: 2,
                ontap: () {
                  controller.tabController.animateTo(2);
                },
              ),
            ],
          ),
          Center(
            child: _navigationMenuItem(
              title: "Team",
              assetsName: 'assets/assets/bottom-team.png',
              selectAssetsName: 'assets/assets/select-bottom-team.png',
              index: 1,
              ontap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigationMenuItem({
    required String title,
    required String assetsName,
    required String selectAssetsName,
    required int index,
    required Callback ontap,
  }) {
    return Obx(
      () => GestureDetector(
        onTap: () {
          controller.changePage(index);
          ontap();
        },
        child: Container(
          width: Get.width * 0.25,
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                controller.bottomMenuIndex.value == index
                    ? selectAssetsName
                    : assetsName,
                height: 24.w,
                width: 24.w,
              ),
              Text(title.tr).descText(
                fontSize: 12,
                color: ColorUtil.fromHexString(
                  controller.bottomMenuIndex.value == index
                      ? "#7857ED"
                      : "#B2B6BF",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

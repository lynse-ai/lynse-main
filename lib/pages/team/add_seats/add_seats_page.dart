import 'package:dting/model/teams_model/seat_package_model.dart';
import 'package:dting/pages/team/add_seats/add_seats_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/image_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class AddSeatsPage extends GetView<AddSeatsController> {
  const AddSeatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Obx(
        () => Container(
          height: Get.height,
          width: Get.width,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/vip/vip-background.png'),
              fit: BoxFit.fill,
            ),
          ),
          padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 34.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 50.w),
              _buildTopAppBar(),
              SizedBox(height: 10.w),
              _buildTopTeam(),
              SizedBox(height: 20.w),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _seatsContent(),
                      SizedBox(height: 50.w),
                      Text(
                        "Seats Purchase".tr,
                      ).boldTitle(fontSize: 16, color: Colors.white),
                      SizedBox(height: 20.w),

                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        childAspectRatio: 1.3, // 宽 / 高，值越大越扁
                        padding: EdgeInsets.zero,
                        physics: NeverScrollableScrollPhysics(),
                        children:
                            controller.seatPackageList
                                .map((point) => _purchaseContent(point))
                                .toList(),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20.w),

              BottomBarWidget(title: "Purchase", ontap: () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _purchaseContent(SeatPackageModel point) {
    return Obx(
      () => GestureDetector(
        onTap: () {
          controller.selectPackage.value = point;
        },
        child: Container(
          alignment: Alignment.center,
          decoration:
              controller.selectPackage.value == point
                  ? BoxDecoration(
                    borderRadius: BorderRadius.circular(24.r),
                    color: ColorUtil.fromHexString("#7857ED", 0.4),
                    border: Border.all(
                      color: ColorUtil.fromHexString("#FFFFFF", 0.2),
                    ),
                  )
                  : BoxDecoration(
                    borderRadius: BorderRadius.circular(24.r),
                    color: ColorUtil.fromHexString("#FFFFFF", 0.1),
                    border: Border.all(
                      color: ColorUtil.fromHexString("#FFFFFF", 0.2),
                    ),
                  ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("${point.teamSeatAmount.toString()} ${"席位".tr}").boldTitle(
                fontSize: 12,
                color: ColorUtil.fromHexString("#FFFFFF"),
              ),
              SizedBox(height: 2.w),
              Text("¥${point.originalPrice.toString()}").descText(
                fontSize: 12,
                color: ColorUtil.fromHexString("#FFFFFF"),
              ),
              SizedBox(height: 2.w),
              point.discountPrice != null
                  ? Text(
                    "¥${point.discountPrice}",
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      decorationColor: ColorUtil.fromHexString("#FFFFFF"),
                      fontSize: 10,
                      color: ColorUtil.fromHexString("#FFFFFF"),
                    ),
                  )
                  : SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seatsContent() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17.r),
        color: ColorUtil.fromHexString("#FFFFFF", 0.1),
        border: Border.all(
          color: ColorUtil.fromHexString("#7857ED", 0.8),
          width: 2.w,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          introduce("Enjoy features of the personal version"),
          introduce("Recording sharing"),
          introduce("Points sharing"),
          introduce("Teamwork space"),
          introduce(
            "Unlimited seats available for purchase",
            showBottomBorder: false,
          ),
        ],
      ),
    );
  }

  Widget introduce(String title, {bool showBottomBorder = true}) {
    return Container(
      height: 40.w,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border:
            showBottomBorder
                ? Border(
                  bottom: BorderSide(
                    color: ColorUtil.fromHexString("#FFFFFF", 0.2),
                  ),
                )
                : null,
      ),
      child: Text(
        title.tr,
      ).boldTitle(color: ColorUtil.fromHexString("#FFFFFF")),
    );
  }

  Widget _buildTopAppBar() {
    return Stack(
      children: [
        Center(
          child: Text(
            "Add Seats".tr,
            style: TextStyle(
              color: ColorUtil.fromHexString("#FFFFFF"),
              fontWeight: FontWeight.w500,
              fontSize: 16.w,
              height: 24 / 16,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () {
              Get.back();
            },
            child: Image.asset(
              'assets/images_v3/back.png',
              width: 24.w,
              height: 24.w,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopTeam() {
    return Obx(
      () => Row(
        children: [
          controller.teamFileController.currentTeam.value.avatarUrl != null
              ? ImageNetwork(
                url: controller.teamFileController.currentTeam.value.avatarUrl,
                size: 40,
              )
              : Image.asset(
                'assets/assets/team-default.png',
                height: 44.w,
                width: 44.w,
              ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        controller
                            .teamFileController
                            .currentTeam
                            .value
                            .teamName,
                      ).boldTitle(
                        fontSize: 16,
                        overflow: TextOverflow.ellipsis,
                        color: ColorUtil.fromHexString("#FFFFFF"),
                        maxLine: 1,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    controller
                                    .teamFileController
                                    .currentTeam
                                    .value
                                    .pointsAmount ==
                                null ||
                            controller
                                    .teamFileController
                                    .currentTeam
                                    .value
                                    .pointsAmount ==
                                0
                        ? SizedBox.shrink()
                        : Row(
                          children: [
                            Text(
                              "${"积分剩余：".tr} ${controller.teamFileController.currentTeam.value.pointsAmountInt - controller.teamFileController.currentTeam.value.usedPointsAmountInt}",
                            ).descText(
                              color: ColorUtil.fromHexString("#FFFFFF"),
                            ),
                            SizedBox(width: 8.w),
                          ],
                        ),
                    Container(
                      height: 18.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: ColorUtil.fromHexString("#FFFFFF"),
                        ),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: Text("Team Edition".tr).descText(
                        fontSize: 10,
                        color: ColorUtil.fromHexString("#FFFFFF"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

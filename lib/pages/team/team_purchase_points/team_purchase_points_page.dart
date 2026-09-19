import 'package:dting/model/teams_model/point_package_model.dart';
import 'package:dting/pages/team/team_purchase_points/team_purchase_points_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/image_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class TeamPurchasePointsPage extends GetView<TeamPurchasePointsController> {
  const TeamPurchasePointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        height: Get.height,
        width: Get.width,
        padding: EdgeInsets.only(left: 20.w, right: 20.w),
        color: ColorUtil.fromHexString("#F2F4F7"),
        child: Obx(
          () => Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 50.w),
                  _buildTopAppBar(),
                  SizedBox(height: 20.w),
                  _teamPurchasePoints(),
                  SizedBox(height: 15.w),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment:
                            controller
                                        .appController
                                        .teamPointPackageList
                                        .length >
                                    2
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10.w,
                            runSpacing: 15.w,
                            children:
                                controller.appController.teamPointPackageList
                                    .map(
                                      (point) => _payPointpurchaseItem(point),
                                    )
                                    .toList(),
                          ),
                          SizedBox(height: 20.w),
                          _pointsBenefits(),
                          SizedBox(height: 120.w),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              Positioned(bottom: 30.w, left: 0, right: 0, child: _bottomPay()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomPay() {
    return GestureDetector(
      onTap: () {
        controller.purchasePointPay();
      },
      child: Container(
        height: 68.w,
        width: Get.width,
        padding: EdgeInsets.only(left: 24.w, right: 10.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ColorUtil.fromHexString("#453D5B"),
              ColorUtil.fromHexString("#1F1E26"),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(54.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "¥".tr,
                    ).descText(fontSize: 16, color: Colors.white, height: 1.8),
                    Text(
                      "${controller.selectPackage.value.discountPrice ?? "0"}",
                    ).mainTitle(fontSize: 24, color: Colors.white),
                  ],
                ),
                RichText(
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.clip,
                  softWrap: true,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "Notice".tr,
                        style: TextStyle(
                          fontFamily: "Fugaz One",
                          color: ColorUtil.fromHexString("#CED1D8"),
                          fontWeight: FontWeight.w400,
                          fontSize: 11.w,
                        ),
                      ),
                      TextSpan(
                        text: "Team".tr,
                        style: TextStyle(
                          fontFamily: "Fugaz One",
                          color: ColorUtil.fromHexString("#7857ED"),
                          fontWeight: FontWeight.w400,
                          fontSize: 11.w,
                        ),
                      ),
                      TextSpan(
                        text: "points".tr,
                        style: TextStyle(
                          fontFamily: "Fugaz One",
                          color: ColorUtil.fromHexString("#CED1D8"),
                          fontWeight: FontWeight.w400,
                          fontSize: 11.w,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              height: 48.w,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ColorUtil.fromHexString("#E4DBFC"),
                    ColorUtil.fromHexString("#B292F5"),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(89.r),
              ),
              child: Text("Purchase".tr).boldTitle(
                color: ColorUtil.fromHexString("#451E1F"),
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamPurchasePoints() {
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
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text("${"teamPointRemaining".tr}：").mainTitle(
                            color: ColorUtil.fromHexString("#7857ED"),
                            fontSize: 17,
                            maxLine: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "${controller.teamFileController.currentTeam.value.remainPointsAmountInt}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20.sp,
                              color: ColorUtil.fromHexString("#7857ED"),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15.w),
                LinearProgressIndicator(
                  value:
                      controller
                          .teamFileController
                          .currentTeam
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
                      "${"points used".tr}：${controller.teamFileController.currentTeam.value.usedPointsAmountInt} ",
                    ).descText(
                      color: ColorUtil.fromHexString("#5D18C3"),
                      fontSize: 10,
                    ),
                    Text(
                      "${"points total".tr}：${controller.teamFileController.currentTeam.value.pointsAmountInt} ",
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

  Widget _payPointpurchaseItem(PointPackageModel point) {
    return Obx(
      () => GestureDetector(
        onTap: () {
          controller.selectPackage.value = point;
        },
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            Container(
              width: 100.w,
              alignment: Alignment.center,
              padding: EdgeInsets.only(
                left: 15.w,
                right: 15,
                bottom: 15,
                top: 30.w,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.r),
                color: ColorUtil.fromHexString("#FFFFFF"),
                border:
                    controller.selectPackage.value == point
                        ? Border.all(color: ColorUtil.fromHexString("#7857ED"))
                        : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("¥".tr).descText(
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        color: ColorUtil.fromHexString('#5B5E68'),
                        decorationColor: ColorUtil.fromHexString('#5B5E68'),
                      ),
                      Text("${point.originalPrice}").descText(
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        color: ColorUtil.fromHexString('#5B5E68'),
                        decorationColor: ColorUtil.fromHexString('#5B5E68'),
                      ),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("¥".tr).mainTitle(fontSize: 14),
                      Text("${point.discountPrice}").mainTitle(fontSize: 22),
                    ],
                  ),
                  SizedBox(height: 2.w),
                  Text("price".tr).descText(
                    fontSize: 12,
                    color: ColorUtil.fromHexString("#7E8492"),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                height: 22.w,
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColorUtil.fromHexString("#7857ED"),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                ),
                child: Text(
                  "${point.pointsAmount} ${"points".tr}",
                ).descText(color: Colors.white, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Obx(
      () => GestureDetector(
        onTap: () {
          Get.back();
        },
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.only(right: 10.w),
              child: Image.asset(
                'assets/images_v3/back.png',
                width: 24.w,
                height: 24.w,
              ),
            ),
            ImageNetwork(
              url: controller.teamFileController.currentTeam.value.avatarUrl,
              size: 40,
              defaultImage: 'assets/images_v3/team-avatar.png',
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                controller.teamFileController.currentTeam.value.teamName,
              ).boldTitle(
                fontSize: 16,
                maxLine: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pointsBenefits() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: ColorUtil.fromHexString("#7857ED"),
          width: 1.w,
        ),
        borderRadius: BorderRadius.circular(5),
        color: ColorUtil.fromHexString("#F3F1FE"),
      ),
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(
            color: ColorUtil.fromHexString("#7857ED"),
            width: 1.w,
          ),
          verticalInside: BorderSide(
            color: ColorUtil.fromHexString("#7857ED"),
            width: 1.w,
          ),
        ),
        children: [
          _tableRow(
            cell1: "EquityItems".tr,
            cell2: "usePoint".tr,
            fontWeight: FontWeight.w500,
          ),
          _tableRow(cell1: "Transcr".tr, cell2: "1/${"minute".tr}"),
          _tableRow(cell1: "Outln".tr, cell2: "1/${"minute".tr}"),
          _tableRow(cell1: "Concl".tr, cell2: "1/${"minute".tr}"),
          _tableRow(cell1: "MindMapped".tr, cell2: "1/${"minute".tr}"),
          _tableRow(cell1: "${"seats".tr}（${"6months".tr}）".tr, cell2: "20"),
          _tableRow(cell1: "${"seats".tr}（${"12months".tr}）".tr, cell2: "35"),
          _tableRow(cell1: "share".tr, cell2: "1/${"once".tr}"),
          _tableRow(cell1: "Export".tr, cell2: "1/${"once".tr}"),
        ],
      ),
    );
  }

  TableRow _tableRow({
    required String cell1,
    required String cell2,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TableRow(
      children: [
        TableCell(
          child: Container(
            height: 40.w,
            alignment: Alignment.center,
            child: Text(
              cell1,
              style: TextStyle(fontWeight: fontWeight, fontSize: 14.w),
            ),
          ),
        ),
        TableCell(
          child: Container(
            height: 40.w,
            alignment: Alignment.center,
            child: Text(
              cell2,
              style: TextStyle(fontWeight: fontWeight, fontSize: 14.w),
            ),
          ),
        ),
      ],
    );
  }
}

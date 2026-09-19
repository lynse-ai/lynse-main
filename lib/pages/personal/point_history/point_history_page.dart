import 'package:dting/model/payment/point_history_log.dart';
import 'package:dting/pages/personal/point_history/point_history_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/datetime_helper.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/nodata_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class PointHistoryPage extends GetView<PointHistoryController> {
  const PointHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidgets.getAppBar(
        title: "PersonalPointsRecord".tr,
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      ),
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      body: Obx(
        () => Container(
          padding: EdgeInsets.only(
            left: 24.w,
            right: 24.w,
            top: 11.w,
            bottom: 14.w,
          ),
          width: Get.width,
          child:
              controller.pointHistoryList.isEmpty
                  ? NoDataWidget(tipText: "noHistoryPoint")
                  : SingleChildScrollView(
                    child: Column(
                      children:
                          controller.pointHistoryList
                              .map((package) => _history(package))
                              .toList(),
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _history(PointHisToryLogModel package) {
    return Container(
      width: Get.width,
      margin: EdgeInsets.only(bottom: 10.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(package.changeTypeString.tr).descText(fontSize: 15),
                SizedBox(height: 7.w),
                Text(package.pointsDetails ?? "").descText(
                  fontSize: 12,
                  color: ColorUtil.fromHexString("#7E8492"),
                ),
                SizedBox(height: 4.w),
                Text(
                  DateTimeHelper.timeCoverToMdHs(package.createTime!),
                ).descText(
                  fontSize: 12,
                  color: ColorUtil.fromHexString("#7E8492"),
                ),
              ],
            ),
          ),
          Text(
            "${package.operationType}${package.pointsAmount}",
          ).mainTitle(fontSize: 18),
        ],
      ),
    );
  }
}

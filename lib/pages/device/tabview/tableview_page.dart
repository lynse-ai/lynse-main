import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

import 'tableview_controller.dart';

class TableViewPage extends GetView<TableViewController> {
  const TableViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(width: 8.w),
          _tabItem(
            assname: "assets/svg/device/translate.svg",
            title: "Transcr".tr,
            index: 0,
          ),
          SizedBox(width: 29.w),
          _tabItem(
            assname: "assets/svg/device/pentool.svg",
            index: 1,
            title: "Concl".tr,
          ),
          SizedBox(width: 29.w),

          _tabItem(
            assname: "assets/svg/device/document.svg",
            index: 2,
            title: "Outln".tr,
          ),
          SizedBox(width: 29.w),

          _tabItem(
            assname: "assets/svg/device/gitpullrequest.svg",
            title: "Mind-mapped".tr,
            index: 3,
          ),
          SizedBox(width: 29.w),
        ],
      ),
    );
  }

  Widget _tabItem({
    required String assname,
    required String title,
    required int index,
  }) {
    return Obx(
      () => GestureDetector(
        onTap: () {
          controller.voiceController.selectAIMenu.value = index;
          // controller.voiceController.switchAIResponse();
        },
        child: Row(
          children: [
            SvgPicture.asset(
              assname,
              width: 18.w,
              height: 18.w,
              color:
                  controller.voiceController.selectAIMenu.value == index
                      ? ColorUtil.fromHexString("#161616")
                      : ColorUtil.fromHexString("#7E8492"),
            ),
            SizedBox(width: 6.w),
            Text(
              title,
              style:
                  controller.voiceController.selectAIMenu.value == index
                      ? TextStyle(
                        color: ColorUtil.fromHexString("#161616"),
                        fontWeight: FontWeight.w600,
                        fontSize: 16.w,
                        height: 18.75 / 16,
                      )
                      : TextStyle(
                        color: ColorUtil.fromHexString("#7E8492"),
                        fontWeight: FontWeight.w400,
                        fontSize: 14.w,
                        height: 16.41 / 14,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

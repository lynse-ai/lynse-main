import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:dting/widgets/input_formatters.dart';
import 'package:dting/widgets/title_bottom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class AddTeamWidget extends GetView<TeamFileController> {
  const AddTeamWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var color = "#7E8492".obs;
    return SafeArea(
      bottom: false,
      child: Container(
        margin: EdgeInsets.only(top: 50.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.w),
            topRight: Radius.circular(20.w),
          ),
          color: ColorUtil.fromHexString("#F2F4F7"),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  TitleBottomWidget(title: "createTeam"),

                  Column(
                    children: [
                      Obx(
                        () => Container(
                          margin: EdgeInsets.only(top: 10.w, bottom: 20.w),
                          child: Image.asset(
                            controller.createTeamAvatatUrl.value,
                            width: 60.w,
                            height: 60.w,
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(bottom: 25.w),
                        width: Get.width,
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 4.w,
                        ),
                        decoration: BoxDecoration(
                          color: ColorUtil.fromHexString('#FFFFFF'),
                          borderRadius: BorderRadius.circular(10.w),
                        ),
                        clipBehavior: Clip.antiAlias,
                        height: 40.w,
                        child: TextField(
                          controller: controller.createTeamController,
                          cursorColor: ColorUtil.fromHexString('#333333'),
                          style: TextStyle(
                            color: ColorUtil.fromHexString('#333333'),
                            fontSize: 14.w,
                            height: 22 / 14,
                          ),
                          onChanged: (value) {
                            if (value.trim().isEmpty) {
                              color.value = "#7E8492";
                            } else {
                              color.value = "#7857ED";
                            }
                          },
                          // inputFormatters: [OnlyLetterNumberFormatter()],
                          decoration: InputDecoration(
                            hintText: "inputTeamName".tr,
                            hintStyle: TextStyle(
                              color: ColorUtil.fromHexString('#B2B6BF'),
                              fontSize: 14.w,
                              height: 22 / 14,
                            ),
                            isDense: true,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 0,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _bottomMenus(color),
                ],
              ),
            ),

            SizedBox(height: 30.w),
          ],
        ),
      ),
    );
  }

  Widget _bottomMenus(RxString color) {
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: BottomBarWidget(
              title: "cancel",
              color: ColorUtil.fromHexString("#E7E9EC"),
              titleColor: ColorUtil.fromHexString("#161616"),
              ontap: () {
                Get.back();
              },
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: BottomBarWidget(
              color: ColorUtil.fromHexString(color.value),
              title: "Create",
              ontap: () {
                controller.createNewTeam();
              },
            ),
          ),
        ],
      ),
    );
  }
}

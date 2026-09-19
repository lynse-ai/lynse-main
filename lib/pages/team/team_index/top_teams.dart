import 'package:dting/model/teams_model/teams_model.dart';
import 'package:dting/pages/team/team_index/add_team.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:dting/widgets/image_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class TopSheetByTeamListWidgets extends GetView<TeamFileController> {
  const TopSheetByTeamListWidgets({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Get.width,
      padding: _getContainerPadding(),
      decoration: _getContainerDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTitle(),
          SizedBox(height: 20.w),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxHeight: 200.w),
              child: SingleChildScrollView(
                child: Column(
                  children:
                      controller.appController.teamsList
                          .map((team) => _teamItem(team))
                          .toList(),
                ),
              ),
            ),
          ),
          DividerWidget(spacer: 5),
          _buildAddDeviceButton(),
        ],
      ),
    );
  }

  EdgeInsets _getContainerPadding() {
    return EdgeInsets.only(left: 20.w, right: 20.w, top: 50.w, bottom: 20.w);
  }

  BoxDecoration _getContainerDecoration() {
    return BoxDecoration(
      color: ColorUtil.fromHexString("#FFFFFF"),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(15.r),
        bottomRight: Radius.circular(15.r),
      ),
    );
  }

  Widget _buildTitle() {
    return GestureDetector(
      onTap: () {
        Get.back();
      },
      child: Row(
        children: [
          Text(
            "changeTeam".tr,
          ).mainTitle(color: ColorUtil.fromHexString("#161616"), fontSize: 15),
          SizedBox(width: 5.w),
          Image.asset(
            'assets/images_v3/chevron-topt.png',
            height: 18.w,
            width: 18.w,
          ),
        ],
      ),
    );
  }

  Widget _buildAddDeviceButton() {
    return GestureDetector(
      onTap: () {
        Get.back();
        controller.getRandomAvatarUrl();
        controller.createTeamController.text = "";
        Get.bottomSheet(
          AddTeamWidget(),
          isDismissible: true,
          isScrollControlled: true,
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(top: 8.w),
        child: Row(
          children: [
            Image.asset(
              'assets/images_v3/add-device.png',
              height: 28.w,
              width: 28.w,
            ),
            SizedBox(width: 10.w),
            Text(
              "createTeam".tr,
            ).descText(color: ColorUtil.fromHexString("#161616"), fontSize: 12),
          ],
        ),
      ),
    );
  }

  Widget _teamItem(TeamsModel team) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            controller.changeToSelectTeam(selectTeam: team);
          },
          child: Container(
            height: 40.w,
            width: double.infinity,
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ImageNetwork(
                  url: team.avatarUrl,
                  size: 28,
                  defaultImage: 'assets/images_v3/team-avatar.png',
                ),
                SizedBox(width: 5.w),
                Expanded(
                  child: Text(
                    team.teamName,
                  ).descText(maxLine: 1, overflow: TextOverflow.ellipsis),
                ),
                SizedBox(width: 20.w),
                _buildArrowIcon(),
              ],
            ),
          ),
        ),
        // DividerWidget(spacer: 5),
      ],
    );
  }

  Widget _buildArrowIcon() {
    return Container(
      padding: EdgeInsets.only(left: 10.w),
      child: Image.asset(
        'assets/images_v3/arrow-right.png',
        width: 24.w,
        height: 24.w,
      ),
    );
  }
}

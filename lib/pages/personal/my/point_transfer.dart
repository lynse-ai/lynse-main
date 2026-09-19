import 'package:dting/model/teams_model/teams_model.dart';
import 'package:dting/pages/personal/my/my_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:dting/widgets/image_network.dart';
import 'package:dting/widgets/title_bottom.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class PointTransferWidget extends GetView<MyController> {
  const PointTransferWidget({super.key});

  @override
  Widget build(BuildContext context) {
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
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部标题
              Padding(
                padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TitleBottomWidget(title: "transPointToTeam"),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${"personalPoint".tr}：").descText(),
                        Text(
                          "${controller.appController.userInfo.value.remainPointsAmountInt}",
                        ).descText(),
                      ],
                    ),
                    SizedBox(height: 15.w),
                    _inputTrantPoint(),
                    SizedBox(height: 15.w),
                    Text("${"selecTeam".tr}：").descText(),
                    SizedBox(height: 15.w),
                  ],
                ),
              ),

              // 中间内容区域（滚动）
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: controller.appController.teamsList.length,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final team =
                              controller.appController.teamsList[index];
                          return teamContent(team);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 10.w),
              BottomBarWidget(title: "trans", ontap: controller.transPoint),
              SizedBox(height: 40.w),
            ],
          ),
        ),
      ),
    );
  }

  Widget teamContent(TeamsModel team) {
    return Obx(
      () => Container(
        height: 48.w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.r),
        ),
        padding: EdgeInsets.symmetric(vertical: 8.w, horizontal: 12.w),
        margin: EdgeInsets.only(bottom: 15.w),
        child: GestureDetector(
          onTap: () {
            controller.tempSelectTeam.value = team;
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ImageNetwork(
                      url: team.avatarUrl,
                      size: 40,
                      defaultImage: 'assets/images_v3/team-avatar.png',
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(team.teamName).descText(
                        color: ColorUtil.fromHexString("#1E1E1E"),
                        fontSize: 16,
                        maxLine: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Image.asset(
                controller.tempSelectTeam.value.id == team.id
                    ? 'assets/images_v3/select-member.png'
                    : 'assets/images_v3/un-select-member.png',
                width: 20.w,
                height: 20.w,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputTrantPoint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("${"tranPointNumber".tr}：").descText(),
        Container(
          height: 34.w,
          width: 120.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            color: Colors.white,
          ),
          alignment: Alignment.centerRight,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: TextField(
            textAlign: TextAlign.right,
            controller: controller.transPointController,
            keyboardType: TextInputType.number,
            cursorColor: ColorUtil.fromHexString('#333333'),
            style: TextStyle(
              color: ColorUtil.fromHexString('#333333'),
              fontWeight: FontWeight.w400,
              fontSize: 13.w,
              height: 14.06 / 12,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly, // 只允许输入数字
            ],
            decoration: InputDecoration(
              hintText: "input".tr,
              hintStyle: TextStyle(
                color: ColorUtil.fromHexString('#B2B6BF'),
                fontWeight: FontWeight.w400,
                fontSize: 13.w,
                height: 14.06 / 12,
              ),
              isDense: true,
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

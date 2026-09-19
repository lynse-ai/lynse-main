import 'package:dting/model/teams_model/teams_model.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/bottom_bar.dart'; 
import 'package:dting/widgets/image_network.dart';
import 'package:dting/widgets/title_bottom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; 
import 'package:get/get.dart';

class SelectShareTeamWidget extends GetView {
  SelectShareTeamWidget({
    super.key,
    required this.copyOrMove,
    required this.isPersonal,
    required this.teamsList,
    required this.onClick,
  });
  bool copyOrMove;
  bool isPersonal;
  List<TeamsModel> teamsList;
  Function(List<TeamsModel> selectTeam, bool copyOrMove, bool isPersonal)
  onClick;

  var tempSelectTeamList = <TeamsModel>[].obs;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SafeArea(
        bottom: false,
        child: Container(
          margin: EdgeInsets.only(top: 50.w),
          padding: EdgeInsets.only(right: 20.w, left: 20.w, bottom: 40.w),
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
              TitleBottomWidget(title: "shareToTeam"),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: teamsList.length,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final team = teamsList[index];
                          return teamContent(team);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10.w),
              _bottomMenus(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomMenus() {
    return Row(
      children: [
        Expanded(
          child: BottomBarWidget(
            title: "cancel",
            color: ColorUtil.fromHexString("#E7E9EC"),
            titleColor: ColorUtil.fromHexString("#161616"),
            ontap: () {
              //  tempSelectTeamList.value = [];
              Get.back();
            },
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: BottomBarWidget(
            title: copyOrMove ? "copyToTeam" : "moveToTeam",
            // color: ColorUtil.fromHexString("#7E8492"),
            ontap: () => onClick(tempSelectTeamList, copyOrMove, isPersonal),
            // {
            //   controller.copyOrMoveFileList(copyOrMove, isPersonal);
            // },
          ),
        ),
      ],
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
            if (copyOrMove) {
              if (tempSelectTeamList.contains(team)) {
                tempSelectTeamList.remove(team);
              } else {
                tempSelectTeamList.add(team);
              }
            } else {
              tempSelectTeamList.value = [];
              tempSelectTeamList.add(team);
            }
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
                tempSelectTeamList.contains(team)
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
}

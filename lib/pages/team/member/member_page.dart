import 'package:dting/model/teams_model/members_model.dart';
import 'package:dting/pages/team/member/permission_setting.dart';
import 'package:dting/pages/team/team_index/invite_member.dart';
import 'package:dting/pages/team/member/member_controller.dart';
import 'package:dting/pages/team/member/more_operations.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/image_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class MemberPage extends GetView<MemberController> {
  const MemberPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidgets.getAppBar(
        title: "teamManage".tr,
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
        actions: [
          GestureDetector(
            onTap: () {
              Get.bottomSheet(
                MoreOperationsByTeamWidget(),
                isDismissible: true,
                isScrollControlled: true,
              );
            },
            child: Text(
              "more2".tr,
            ).descText(color: ColorUtil.fromHexString("#7857ED")),
          ),
        ],
      ),
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      body: SafeArea(
        child: Obx(
          () => Container(
            width: Get.width,
            height: Get.height,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.w),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _teamPoints(),
                  SizedBox(height: 20.w),
                  // _buildTeamInfo(),
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.white,
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          controller
                                      .teamFileController
                                      .currentTeam
                                      .value
                                      .currentCustomerRole ==
                                  0
                              ? SizedBox()
                              : GestureDetector(
                                onTap: () {
                                  Get.bottomSheet(
                                    isDismissible: true,
                                    InviteMemberWidget(
                                      onClick: (List<String> val) {
                                        controller.inviteMemberJoinOurTeam(
                                          inviteePhoneList: val,
                                        );
                                      },
                                    ),
                                    isScrollControlled: true,
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: ColorUtil.fromHexString(
                                          '#EBECF0',
                                        ),
                                        width: 1.w,
                                      ),
                                    ),
                                  ),
                                  height: 48.w,
                                  child: Row(
                                    children: [
                                      Image.asset(
                                        "assets/images_v3/team-invite_member.png",
                                        width: 28.w,
                                        height: 28.w,
                                      ),
                                      SizedBox(width: 10.w),
                                      Text("inviteMember".tr).descText(),
                                    ],
                                  ),
                                ),
                              ),
                          ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: controller.membersList.length,
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final member = controller.membersList[index];
                              return memberContent(member, isFirst: index == 0);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamPoints() {
    return GestureDetector(
      onTap: () {
        // NavigationUtils.toPurchasePoints();
      },
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Container(
            width: Get.width,
            padding: EdgeInsets.only(
              top: 30.w,
              left: 14.w,
              right: 14.w,
              bottom: 15.w,
            ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text("${"payPoint".tr}：").mainTitle(
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
                Row(
                  children: [
                    Text("BenefitsDes".tr).descText(
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
                SizedBox(height: 10.w),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${"Seatusage".tr}：${controller.teamFileController.currentTeam.value.membersInt}/${controller.teamFileController.currentTeam.value.memberCapacity}",
                            // "席位使用情况：${controller.teamFileController.currentTeam.value.members != null ? controller.teamFileController.currentTeam.value.members!.length : 0}/${controller.teamFileController.currentTeam.value.memberCapacity}",
                          ).descText(
                            fontSize: 10,
                            color: ColorUtil.fromHexString("#7857ED"),
                          ),
                          SizedBox(height: 8.w),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value:
                                      controller
                                          .teamFileController
                                          .currentTeam
                                          .value
                                          .percentMembersDouble,
                                  backgroundColor: ColorUtil.fromHexString(
                                    "#D9E4FF",
                                  ),
                                  borderRadius: BorderRadius.circular(100.r),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    ColorUtil.fromHexString("#7857ED"),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Visibility(
                      visible:
                          controller
                              .teamFileController
                              .currentTeam
                              .value
                              .memberCapacity ==
                          controller
                              .teamFileController
                              .currentTeam
                              .value
                              .membersInt,
                      child: Container(
                        height: 29.w,
                        margin: EdgeInsets.only(left: 15.w),
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
                          child: Text(
                            'Seats Purchase'.tr,
                          ).mainTitle(fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: IntrinsicWidth(
                  child: Container(
                    height: 29.w,
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
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(15),
                        bottomLeft: Radius.circular(15),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    child: ShaderMask(
                      shaderCallback:
                          (bounds) => LinearGradient(
                            colors: [
                              ColorUtil.fromHexString("#816EE4"),
                              ColorUtil.fromHexString("#FF94F4"),
                            ],
                          ).createShader(
                            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                          ),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        controller
                            .teamFileController
                            .currentTeam
                            .value
                            .teamName,
                      ).mainTitle(
                        fontSize: 15,
                        maxLine: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget memberContent(MembersModel member, {bool? isFirst}) {
    return Container(
      height: 48.w,
      padding: EdgeInsets.symmetric(vertical: 8.w),
      decoration: BoxDecoration(
        border:
            isFirst != null && isFirst
                ? null
                : Border(
                  top: BorderSide(
                    color: ColorUtil.fromHexString('#EBECF0'),
                    width: 1.w,
                  ),
                ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ImageNetwork(url: member.avatarUrl, size: 28),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(member.nickname ?? "--").descText(
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
          GestureDetector(
            onTap: () {
              if (isFirst != null && !isFirst) {
                //并不是第一个数据
                if (controller
                            .teamFileController
                            .currentTeam
                            .value
                            .currentCustomerRole ==
                        2 ||
                    (controller
                                .teamFileController
                                .currentTeam
                                .value
                                .currentCustomerRole !=
                            0 &&
                        member.role == 0)) {
                  controller.selectMember.value = member;
                  Get.bottomSheet(
                    PermissionSettingWidget(),
                    isDismissible: true,
                    isScrollControlled: true,
                  );
                }
              }
            },
            child: Row(
              children: [
                Text(member.roleString.tr).descText(
                  color: ColorUtil.fromHexString("#000000", 0.3),
                  fontSize: 12,
                ),
                isFirst != null && isFirst
                    ? SizedBox()
                    : controller
                            .teamFileController
                            .currentTeam
                            .value
                            .currentCustomerRole ==
                        2
                    ? Container(
                      padding: EdgeInsets.only(left: 5.w),
                      child: Image.asset(
                        'assets/images_v3/arrow-right.png',
                        width: 24.w,
                        height: 24.w,
                      ),
                    )
                    : controller
                                .teamFileController
                                .currentTeam
                                .value
                                .currentCustomerRole !=
                            0 &&
                        member.role == 0
                    ? Container(
                      padding: EdgeInsets.only(left: 5.w),
                      child: Image.asset(
                        'assets/images_v3/arrow-right.png',
                        width: 24.w,
                        height: 24.w,
                      ),
                    )
                    : SizedBox(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

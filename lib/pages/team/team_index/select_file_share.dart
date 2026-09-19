import 'package:dting/model/teams_model/members_model.dart';
import 'package:dting/pages/team/member/member_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/image_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class SelectFileSharePage extends GetView<MemberController> {
  const SelectFileSharePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidgets.getAppBar(
        title: "selectOwner".tr,
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
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
        ),
      ),
    );
  }

  Widget memberContent(MembersModel member, {bool? isFirst}) {
    return Obx(
      () => Container(
        height: 48.w,
        padding: EdgeInsets.symmetric(vertical: 8.w, horizontal: 4.w),
        decoration: BoxDecoration(
          border:
              isFirst != null && isFirst
                  ? Border(
                    top: BorderSide(
                      color: ColorUtil.fromHexString('#EBECF0'),
                      width: 1.w,
                    ),
                  )
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  member.avatarUrl != null
                      ? ImageNetwork(url: member.avatarUrl, size: 40)
                      : Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100.r),
                        ),
                        child: Image.asset(
                          'assets/images_v3/team-avatar.png',
                          width: 28.w,
                          height: 28.w,
                        ),
                      ),
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
                controller.selectMember.value = member;
              },
              child: Image.asset(
                controller.selectMember.value.memberId == member.memberId
                    ? 'assets/images_v3/select-member.png'
                    : 'assets/images_v3/un-select-member.png',
                width: 20.w,
                height: 20.w,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

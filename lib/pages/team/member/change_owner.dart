import 'package:dting/model/teams_model/members_model.dart';
import 'package:dting/pages/team/member/member_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/image_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class ChangeOwnerWidget extends GetView<MemberController> {
  const ChangeOwnerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    var tempMember = MembersModel.genDefault().obs; //当前界面选择要转移所有者的成员

    return Scaffold(
      appBar: AppBarWidgets.getAppBar(
        title: "selectOwner".tr,
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      ),
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      body: SafeArea(
        child: Obx(
          () => Column(
            children: [
              /// 上方可滚动的内容
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.white,
                        ),
                        margin: EdgeInsets.only(
                          left: 24.w,
                          right: 24.w,
                          bottom: 24.w,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: controller.membersList.length,
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final member = controller.membersList[index];
                            return memberContent(
                              member,
                              isFirst: index == 0,
                              tempMember: tempMember,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              /// 底部固定按钮
              Container(
                margin: EdgeInsets.only(bottom: 34.w, left: 24.w, right: 24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _confirmChangeOwner(tempMember),
                    // SizedBox(height: 20.w),
                    // _cancelChangeOwner(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SizedBox _cancelChangeOwner() {
  //   return SizedBox(
  //     height: 48.w,
  //     child: OutlinedButton(
  //       onPressed: () {
  //         //
  //       },
  //       style: OutlinedButton.styleFrom(
  //         foregroundColor: ColorUtil.fromHexString("#7857ED"),
  //         minimumSize: const Size(double.infinity, 48.0),
  //         side: BorderSide(color: ColorUtil.fromHexString("#7857ED")),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(12.r),
  //         ),
  //       ),
  //       child: Text(
  //         '取消更改'.tr,
  //         style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
  //       ),
  //     ),
  //   );
  // }

  Widget _confirmChangeOwner(Rx<MembersModel> tempMember) {
    return GestureDetector(
      onTap: () {
        if (tempMember.value.role != 2) {
          DialogHelper.showDialogByChild(
            title: "transOwner",
            child: Text(
              '${"confirmTrans".tr}“${tempMember.value.nickname}”'.tr,
              textAlign: TextAlign.center,
            ),
            cancelText: "cancel",
            okText: "confirm",
            okOntap: () {
              controller.selectMember.value = tempMember.value;
              controller.administrativeForMember(roleInt: 2, back: true);
              Get.back();
            },
          );
        } else {
          DialogHelper.showToastDialog("NoActionRequired");
        }
      },
      child: Container(
        height: 48.w,
        width: Get.width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: ColorUtil.fromHexString("#7857ED"),
        ),
        child: Text(
          'ConfirmChanges'.tr,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget memberContent(
    MembersModel member, {
    bool? isFirst,
    required Rx<MembersModel> tempMember,
  }) {
    if (member.role == 2) {
      tempMember.value = member;
    }
    return Obx(
      () => Container(
        height: 48.w,
        padding: EdgeInsets.symmetric(vertical: 8.w, horizontal: 4.w),
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
        child: GestureDetector(
          onTap: () {
            tempMember.value = member;
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // member.avatarUrl != null
                    //     ?
                    ImageNetwork(url: member.avatarUrl, size: 40),
                    // : Container(
                    //   decoration: BoxDecoration(
                    //     borderRadius: BorderRadius.circular(100.r),
                    //   ),
                    //   child: Image.asset(
                    //     'assets/images_v3/team-avatar.png',
                    //     width: 28.w,
                    //     height: 28.w,
                    //   ),
                    // ),
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
              Image.asset(
                tempMember.value.id == member.id
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

import 'package:dting/pages/home/folder_manage/widget/edit_text_widget.dart';
import 'package:dting/pages/team/member/member_controller.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/bottom_row_menu_item_widget.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/title_bottom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class MoreOperationsByTeamWidget extends GetView<MemberController> {
  const MoreOperationsByTeamWidget({super.key});

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  TitleBottomWidget(title: "more"),

                  BottomRowMenuItemWidget(
                    text: "editTeamName",
                    showArrow: false,
                    ontap: () {
                      Get.bottomSheet(
                        EditTextWidget(
                          onClick: (bool? val, String editText) {
                            if (val != null && val) {
                              controller.editTeamName(editText);
                            }
                          },
                          needEditText:
                              controller
                                  .teamFileController
                                  .currentTeam
                                  .value
                                  .teamName,
                          title: "editTeamName",
                        ),
                        isScrollControlled: true,
                      );
                    },
                  ),
                  controller
                              .teamFileController
                              .currentTeam
                              .value
                              .currentCustomerRole ==
                          2
                      ? BottomRowMenuItemWidget(
                        text: "transOwner",
                        showArrow: false,
                        ontap: () {
                          NavigationUtils.toChangeMembers();
                        },
                      )
                      : SizedBox(),

                  BottomRowMenuItemWidget(
                    text:
                        controller
                                    .teamFileController
                                    .currentTeam
                                    .value
                                    .currentCustomerRole ==
                                2
                            ? "Disbandment"
                            : "Exit",
                    showArrow: false,
                    ontap: () {
                      DialogHelper.showDialogByChild(
                        cancelText: "cancel",
                        title:
                            controller
                                        .teamFileController
                                        .currentTeam
                                        .value
                                        .currentCustomerRole ==
                                    2
                                ? "confirmDisbandment"
                                : "confirmExit", //【${controller.teamFileController.currentTeam.value.teamName}】
                        child: Text(
                          controller
                                      .teamFileController
                                      .currentTeam
                                      .value
                                      .currentCustomerRole ==
                                  2
                              ? "DisbandmentTip".tr
                              : "ExitTip".tr,
                          textAlign: TextAlign.center,
                        ),
                        okOntap: () {
                          controller.deleteOrLeaveTeam();
                          Get.back();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 12.w),
          ],
        ),
      ),
    );
  }
}

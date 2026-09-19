import 'package:dting/pages/home/folder_manage/widget/edit_text_widget.dart';
import 'package:dting/pages/team/member/member_controller.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/bottom_row_menu_item_widget.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:dting/widgets/title_bottom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class PermissionSettingWidget extends GetView<MemberController> {
  const PermissionSettingWidget({super.key});

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
                  DividerWidget(spacer: 10),
                  Visibility(
                    visible:
                        controller
                            .teamFileController
                            .currentTeam
                            .value
                            .currentCustomerRole ==
                        2,
                    child: BottomRowMenuItemWidget(
                      text:
                          "${"set".tr}${controller.selectMember.value.role == 0 ? "manager".tr : "member".tr}",
                      showArrow: false,
                      ontap: () {
                        controller.administrativeForMember();
                      },
                    ),
                  ),

                  BottomRowMenuItemWidget(
                    text:
                        controller
                                    .teamFileController
                                    .currentTeam
                                    .value
                                    .currentCustomerRole !=
                                0
                            ? "removeMember"
                            : "Exit",
                    // text:
                    //     controller
                    //                 .teamFileController
                    //                 .currentTeam
                    //                 .value
                    //                 .currentCustomerRole !=
                    //             0
                    //         ? "从团队中移除成员"
                    //         : "退出团队",
                    showArrow: false,
                    ontap: () {
                      DialogHelper.showDialogByChild(
                        cancelText: "cancel",
                        child: Text(
                          controller
                                      .teamFileController
                                      .currentTeam
                                      .value
                                      .currentCustomerRole !=
                                  0
                              ? '${"confirmMoveItem".tr}"${controller.selectMember.value.nickname}"${"removeTeam".tr}'
                              : "ExitTip".tr,
                          textAlign: TextAlign.center,
                        ),
                        okOntap: () {
                          controller.removeMemberOrQuitTeam();
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

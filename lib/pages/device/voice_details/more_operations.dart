import 'package:dting/pages/device/voice_details/select_share_team_page.dart';
import 'package:dting/pages/device/voice_details/voicedetails_controller.dart';
import 'package:dting/pages/device/widget/language_list_widget.dart';
import 'package:dting/pages/home/folder_manage/folder_manage_controller.dart';
import 'package:dting/pages/home/folder_manage/widget/edit_text_widget.dart';
import 'package:dting/pages/home/folder_manage/widget/move_file_to_otherfolder_widget.dart';
import 'package:dting/router/modules/translate_router.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/bottom_row_menu_item_widget.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:dting/widgets/title_bottom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class VoiceMoreOperationsWidget extends GetView<VoiceDetailsController> {
  VoiceMoreOperationsWidget({super.key, this.isPersonal = true});
  bool isPersonal;
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
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        _menuItemWidget(
                          text: "rename",
                          ontap: () {
                            Get.back();
                            Get.bottomSheet(
                              EditTextWidget(
                                needEditText:
                                    controller
                                        .appController
                                        .selectFileInfo
                                        .value
                                        .originalFilename ??
                                    "",
                                title: "EditFileName",
                                onClick: (bool? val, String editText) {
                                  if (val != null && val) {
                                    controller.reNameFile(editText);
                                  }
                                },
                              ),
                              isScrollControlled: true,
                            );
                          },
                        ),
                        DividerWidget(spacer: 0),
                        Visibility(
                          visible: isPersonal,
                          child: Column(
                            children: [
                              _menuItemWidget(
                                text: "move",
                                ontap: () {
                                  Get.back();
                                  Get.put(SideBarController());
                                  Get.bottomSheet(
                                    MoveFileToOtherfolderWidget(
                                      selectRemoveVoiceList: [
                                        controller
                                            .appController
                                            .selectFileInfo
                                            .value,
                                      ],
                                    ),
                                    isScrollControlled: true,
                                  );
                                },
                              ),
                              DividerWidget(spacer: 0),
                            ],
                          ),
                        ),
                        // _menuItemWidget(
                        //   text: "transOtherLangage",
                        //   ontap: () {
                        //     Get.bottomSheet(
                        //       LanguageListWidget(title: "transOtherLangage".tr),
                        //       isScrollControlled: true,
                        //     );
                        //   },
                        // ),
                        // DividerWidget(spacer: 0),
                        // if (controller.selectAIMenu.value == 2)
                        //   _menuItemWidget(
                        //     text: "translatePromptModel",
                        //     ontap: () {
                        //       Get.back();
                        //       Get.toNamed(TranslateRouter.promptListPage);
                        //     },
                        //   ),
                      ],
                    ),
                  ),
                  SizedBox(height: 15.w),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        _menuItemWidget(
                          text: "copyToTeam",
                          ontap: () {
                            Get.back();
                            Get.bottomSheet(
                              SelectShareTeamWidget(
                                copyOrMove: true,
                                isPersonal: isPersonal,
                                teamsList: controller.appController.teamsList,
                                onClick: (selectTeam, copyOrMove, isPersonal) {
                                  controller.copyOrMoveFileList(
                                    copyOrMove: copyOrMove,
                                    isPersonal: isPersonal,
                                    selectTeamList: selectTeam,
                                  );
                                },
                              ),
                              isScrollControlled: true,
                            );
                          },
                        ),
                        DividerWidget(spacer: 0),
                        _menuItemWidget(
                          text: "moveToTeam",
                          ontap: () {
                            Get.back();
                            Get.bottomSheet(
                              SelectShareTeamWidget(
                                copyOrMove: false,
                                isPersonal: isPersonal,
                                teamsList: controller.appController.teamsList,
                                onClick: (selectTeam, copyOrMove, isPersonal) {
                                  controller.copyOrMoveFileList(
                                    copyOrMove: copyOrMove,
                                    isPersonal: isPersonal,
                                    selectTeamList: selectTeam,
                                  );
                                },
                              ),
                              isScrollControlled: true,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 15.w),

                  BottomRowMenuItemWidget(
                    text: "feedback",
                    showArrow: false,
                    ontap: () {
                      NavigationUtils.toHelpAndFeedBack();
                    },
                  ),

                  BottomRowMenuItemWidget(
                    text: "delete",
                    showArrow: false,
                    ontap: () {
                      DialogHelper.showDialogByChild(
                        title: 'delete',
                        cancelText: "cancel",
                        child: Text(
                          "isDeleteSeletVoice".tr,
                          textAlign: TextAlign.center,
                        ),
                        okOntap: () {
                          controller.deletePsonalOrTeamVoice();
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

  Widget _menuItemWidget({required String text, required VoidCallback ontap}) {
    return GestureDetector(
      onTap: ontap,
      child: Container(
        height: 43.w,
        width: Get.width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
        ),
        child: Text(text.tr).descText(fontSize: 12),
      ),
    );
  }
}

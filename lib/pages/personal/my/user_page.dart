import 'package:dting/pages/home/folder_manage/widget/edit_text_widget.dart';
import 'package:dting/pages/personal/my/my_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/bottom_botton.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:dting/widgets/image_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

class UserPage extends GetView<MyController> {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
        appBar: AppBarWidgets.getAppBar(
          title: "AccountAndInformation".tr,
          textAlign: TextAlign.center,
          backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
        ),
        body: Stack(
          children: [
            // 主体内容
            Container(
              width: Get.width,
              color: ColorUtil.fromHexString("#F2F4F7"),
              padding: EdgeInsets.only(left: 24.w, right: 24.w, top: 10.w),
              child: Column(
                children: [
                  _profilePicture(),
                  SizedBox(height: 20.w),
                  _content(),
                  SizedBox(height: 40.w),
                ],
              ),
            ),

            // 固定底部按钮
            Positioned(
              left: 24.w,
              right: 24.w,
              bottom: 54.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _logoutUI(),
                  SizedBox(height: 20.w),
                  _cancelAccount(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cancelAccount() {
    return Container(
      height: 48.w,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          DialogHelper.showDialogByChild(
            title: "cancellationAccount",
            child: Text(
              'cancellationAccountTip'.tr,
              textAlign: TextAlign.center,
            ),
            cancelText: "cancel",
            okText: "confirm",
            okOntap: () {
              controller.cancelAccount();
            },
          );
        },
        child: Text(
          'CancelAccount'.tr,
        ).boldTitle(color: ColorUtil.fromHexString("#7857ED"), fontSize: 16),
      ),
    );
  }

  Widget _logoutUI() {
    return GestureDetector(
      onTap: () {
        DialogHelper.showDialogByChild(
          title: "LogOut",
          child: Text('confirmLogOut'.tr, textAlign: TextAlign.center),
          cancelText: "cancel",
          okText: "confirm",
          okOntap: () {
            controller.loginOut();
          },
        );
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
          'LogOut'.tr,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Obx(
      () => Container(
        padding: EdgeInsets.only(left: 10.w, right: 10.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.w),
          color: ColorUtil.fromHexString("#FFFFFF"),
        ),
        child: Column(
          children: [
            _menuCard(
              title: "Nickname",
              svgUrl: "assets/images_v3/icon_my_page_device_manage.png",
              ontap: () {
                Get.bottomSheet(
                  EditTextWidget(
                    needEditText:
                        controller.appController.userInfo.value.nickname ??
                        "--",
                    title: "EditNickname",
                    onClick: (bool? val, String editText) {
                      if (val != null && val) {
                        controller.editNiceName(editText);
                      }
                    },
                  ),
                  isScrollControlled: true,
                );
              },
              rightTitle:
                  controller.appController.userInfo.value.nickname ?? "",
            ),
            DividerWidget(spacer: 0),
            _menuCard(
              title: "myPhone",
              svgUrl: "assets/images_v3/icon_my_page_device_manage.png",
              showBack: true,
              ontap: () {
                Get.bottomSheet(
                  EditTextWidget(
                    needEditText:
                        controller.appController.userInfo.value.phone ?? "--",
                    title: "EditPhone",
                    onClick: (bool? val, String editText) {
                      if (val != null && val) {
                        controller.editPhone(editText);
                      }
                    },
                  ),
                  isScrollControlled: true,
                );
              },
              rightTitle: controller.appController.userInfo.value.phone ?? "",
            ),
            DividerWidget(spacer: 0),
            _menuCard(
              title: "wechat",
              svgUrl: "assets/images_v3/icon_my_page_device_manage.png",
              ontap: () {
                //
              },
            ),
            DividerWidget(spacer: 0),
            _menuCard(
              title: "appleID",
              svgUrl: "assets/images_v3/icon_my_page_device_manage.png",
              ontap: () {
                //
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _rebindPhoneCard() {
    return Container();
  }

  Widget _menuCard({
    required String title,
    String svgUrl = "assets/images_v3/icon_my_page_device_manage.png",
    Callback? ontap,
    bool showBack = true,
    String? rightTitle,
  }) {
    return GestureDetector(
      onTap: ontap,
      child: Container(
        height: 50.w,
        width: Get.width,
        color: ColorUtil.fromHexString("#FFFFFF"),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title.tr).descText(color: ColorUtil.fromHexString("#1E1E1E")),
            showBack
                ? Row(
                  children: [
                    Text(rightTitle ?? "").descText(
                      color: ColorUtil.fromHexString("#7E8492"),
                      fontSize: 12,
                    ),
                    Container(
                      padding: EdgeInsets.only(left: 10.w),
                      child: Image.asset(
                        'assets/images_v3/arrow-right.png',
                        width: 21.w,
                        height: 24.w,
                      ),
                    ),
                  ],
                )
                : Text(rightTitle ?? "").descText(
                  color: ColorUtil.fromHexString("#7E8492"),
                  fontSize: 12,
                ),
          ],
        ),
      ),
    );
  }

  Widget _profilePicture() {
    return GestureDetector(
      onTap: () {
        bottomSheetByChangeUserImage();
      },
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Obx(
            () => ImageNetwork(
              url: controller.appController.userInfo.value.avatarUrl,
              size: 80,
            ),
          ),
          Image.asset('assets/images_v3/camera.png', width: 26.w, height: 26.w),
        ],
      ),
    );
  }

  bottomSheetByChangeUserImage() {
    var changeUserImage = "gallery".obs;
    return showModalBottomSheet(
      context: Get.context!,
      builder: (BuildContext context) {
        return Obx(
          () => Container(
            padding: EdgeInsets.only(bottom: 20.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.w),
                topRight: Radius.circular(20.w),
              ),
              color: ColorUtil.fromHexString("#FFFFFF"),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 44.w,
                  alignment: Alignment.center,
                  child: Text(
                    "editUserAvatar".tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ColorUtil.fromHexString("#1D2129"),
                      fontWeight: FontWeight.w400,
                      fontSize: 14.w,
                      height: 24 / 14,
                    ),
                  ),
                ),
                Divider(color: ColorUtil.fromHexString("#EBECF0"), height: 1.w),
                SizedBox(height: 12.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: GestureDetector(
                    onTap: () {
                      changeUserImage.value = "gallery";
                    },
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          changeUserImage.value == "gallery"
                              ? "assets/svg/device/selectradio.svg"
                              : "assets/svg/device/radio.svg",
                          height: 20.w,
                          width: 20.w,
                        ),

                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            "gallery".tr,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: ColorUtil.fromHexString("#1E1E1E"),
                              fontWeight: FontWeight.w400,
                              fontSize: 16.w,
                              height: 19 / 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: GestureDetector(
                    onTap: () {
                      changeUserImage.value = "camera";
                    },
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          changeUserImage.value == "camera"
                              ? "assets/svg/device/selectradio.svg"
                              : "assets/svg/device/radio.svg",
                          height: 20.w,
                          width: 20.w,
                        ),

                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            "camera".tr,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: ColorUtil.fromHexString("#1E1E1E"),
                              fontWeight: FontWeight.w400,
                              fontSize: 16.w,
                              height: 19 / 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30.w),

                BottomBottonWidget(
                  text: "confirm".tr,
                  width: Get.width,
                  backgroundColor: ColorUtil.fromHexString("#7857ED"),
                  ontap: () {
                    controller.swithchImageSource(changeUserImage.value);
                  },
                ),
                SizedBox(height: 10.w),
              ],
            ),
          ),
        );
      },
    );
  }
}

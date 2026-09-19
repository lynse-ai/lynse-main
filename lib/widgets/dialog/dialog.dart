import 'dart:io';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:dting/model/device_model/connect_device_files_model.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';
import 'package:dting/utils/datetime_helper.dart';
import 'package:filesize/filesize.dart';
import 'package:dting/store/dting_store.dart';

class DialogHelper {
  DialogHelper._();

  static showToastDialog(String msg, {int duration = 2, Callback? togo}) {
    OverlayEntry overlayEntry;
    OverlayState overlayState = Overlay.of(Get.context!); // 获取当前Overlay状态
    overlayEntry = OverlayEntry(
      builder:
          (context) => Center(
            child: GestureDetector(
              onTap: togo,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.w),
                margin: EdgeInsets.symmetric(horizontal: 20.w),
                decoration: BoxDecoration(
                  color: ColorUtil.fromHexString("#000000", 0.5),
                  borderRadius: BorderRadius.circular(12.w),
                ),
                child: Text(
                  msg.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: ColorUtil.fromHexString('#FFFFFF'),
                    fontSize: 16.w,
                    height: 20 / 16,
                  ),
                ),
              ),
            ),
          ),
    );
    overlayState.insert(overlayEntry);
    Future.delayed(Duration(seconds: duration)).then((_) {
      overlayEntry.remove();
    });
  }

  static notConnectDeviceTip({required Callback searchDevice}) {
    showDialog(
      context: Get.context!,
      barrierDismissible: true, // 点击空白处关闭
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white,
          title: Padding(
            padding: EdgeInsets.only(top: 20.w, left: 20.w, right: 20.w),
            child: Center(
              child: Text(
                "notRecording".tr,
              ).mainTitle(fontSize: 18, textAlign: TextAlign.center),
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 30.w,
          ),
          contentPadding: EdgeInsets.zero,
          titlePadding: EdgeInsets.zero,
          actions: [
            Column(
              children: [
                GestureDetector(
                  onTap: searchDevice,
                  child: Container(
                    width: Get.width,
                    height: 44.w,
                    margin: EdgeInsets.only(bottom: 20.w),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: ColorUtil.fromHexString("#7857ED"),
                    ),
                    child: Text(
                      "findDevice".tr,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                GestureDetector(
                  onTap: () => Get.back(),
                  child: Container(
                    width: Get.width,
                    height: 44.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ColorUtil.fromHexString("#7857ED"),
                        width: 1.w,
                      ),
                      color: Colors.white,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "cancel".tr,
                      style: TextStyle(
                        color: ColorUtil.fromHexString("#7857ED"),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static showTipDialog({
    required String message,
    String title = "delete",
    String okText = "confirm",
    String? cancelText,
    Callback? okOntap,
    Callback? cancelOntap,
  }) {
    Get.dialog(
      AlertDialog(
        elevation: 24.0, // 增加阴影层级
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        title: Padding(
          padding: EdgeInsets.only(top: 20.w, left: 20.w, right: 20.w),
          child: Center(
            child: Text(
              title.tr,
            ).mainTitle(fontSize: 18, textAlign: TextAlign.center),
          ),
        ),
        content: Container(
          padding: EdgeInsets.only(
            top: 10.w,
            left: 10.w,
            right: 10.w,
            bottom: 15.w,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: ColorUtil.fromHexString("#E5E6EB")),
            ),
          ),
          child: Text(message.tr, textAlign: TextAlign.center),
        ),
        actionsPadding: EdgeInsets.zero,
        contentPadding: EdgeInsets.zero,
        titlePadding: EdgeInsets.zero,
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              cancelText != null
                  ? Expanded(
                    child: GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        width: Get.width,
                        height: 44.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                          ),
                          border: Border(
                            right: BorderSide(
                              color: ColorUtil.fromHexString("#E5E6EB"),
                              width: 1.w,
                            ),
                            bottom: BorderSide(
                              color: ColorUtil.fromHexString("#E5E6EB"),
                              width: 1.w,
                            ),
                          ),
                        ),
                        child: Text(
                          cancelText.tr,
                          style: TextStyle(
                            color: ColorUtil.fromHexString("#7857ED"),
                          ),
                        ),
                      ),
                    ),
                  )
                  : SizedBox(),
              Expanded(
                child: GestureDetector(
                  onTap: okOntap,
                  child: Container(
                    width: Get.width,
                    height: 44.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      color: Colors.white,
                    ),
                    alignment: Alignment.center,
                    child: Text(okText.tr, style: TextStyle(color: Colors.red)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      barrierDismissible: true, // 点击空白处关闭
      barrierColor: Colors.black.withOpacity(0.5), // 设置半透明黑色背景遮罩
    );
  }

  static showConnectDeviceFiles({
    required List<ConnectDeviceFilesModel> fileList,
    required Function(int, int) okOntap,
    Callback? cancelOntap,
    String okText = "confirm",
    String cancelText = "cancel",
  }) {
    final appController = Get.find<DtingStore>();
    return showOkCancelAlertDialog(
      context: Get.context!,
      builder: (BuildContext context, Widget child) {
        return Obx(
          () => AlertDialog(
            titlePadding: EdgeInsets.zero,
            contentPadding: EdgeInsets.symmetric(
              vertical: 6.w,
              horizontal: 12.w,
            ),
            backgroundColor: ColorUtil.fromHexString("#FFFFFF"),
            title: Container(
              padding: EdgeInsets.symmetric(vertical: 10.w),
              alignment: Alignment.center,
              child: Text(
                "selectFile".tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ColorUtil.fromHexString("#1D2129"),
                  fontWeight: FontWeight.w500,
                  fontSize: 17.w,
                  height: 24 / 17,
                ),
              ),
            ),
            content: Container(
              constraints: BoxConstraints(maxHeight: Get.width),
              decoration: BoxDecoration(
                color: ColorUtil.fromHexString('#F8F8F8'),
              ),
              width: Get.width,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      fileList
                          .map(
                            (file) => GestureDetector(
                              onTap: () {
                                appController.uploadFileSn.value = file.sn;
                              },
                              child: deviceFile(
                                selectSN: appController.uploadFileSn,
                                file: file,
                                isUploading:
                                    appController.deviceFileUploading.value,
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ),
            actionsPadding: EdgeInsets.only(bottom: 12.w, top: 12.w),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () {
                      cancelOntap ?? Get.back();
                    },
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(
                        cancelText.tr,
                        style: TextStyle(
                          color: ColorUtil.fromHexString("#F11212"),
                          fontWeight: FontWeight.w400,
                          fontSize: 16.w,
                          height: 22 / 16,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () {
                        if (appController.deviceFileUploading.value) {
                          return;
                        }

                        if (appController.uploadFileSn.value.isEmpty) {
                          DialogHelper.showToastDialog("selectFile".tr);
                          return;
                        }

                        okOntap(
                          int.tryParse(appController.uploadFileSn.value) ?? 0,
                          0,
                        );
                      },
                      child: Text(
                        "BluetoothTransfer".tr,
                        style: TextStyle(
                          color: ColorUtil.fromHexString("#35373D"),
                          fontWeight: FontWeight.w400,
                          fontSize: 16.w,
                          height: 22 / 16,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    // width: MediaQuery.of(context).size.width / 4,
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () {
                        if (Platform.isIOS) {
                          // iOS端WiFi快传功能提示
                          DialogHelper.showToastDialog("selectBlue");
                          return;
                        }
                        if (appController.deviceFileUploading.value) {
                          return;
                        }

                        if (appController.uploadFileSn.value.isEmpty) {
                          DialogHelper.showToastDialog("selectFile");
                          return;
                        }

                        okOntap(
                          int.tryParse(appController.uploadFileSn.value) ?? 0,
                          1,
                        );
                      },
                      child: Text(
                        "WiFiTransfer".tr,
                        style: TextStyle(
                          color: ColorUtil.fromHexString("#35373D"),
                          fontWeight: FontWeight.w400,
                          fontSize: 16.w,
                          height: 22 / 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget deviceFile({
    required RxString selectSN,
    required ConnectDeviceFilesModel file,
    required isUploading,
  }) {
    final String fileSize = "${filesize(file.size)}";
    final String startTime = file.startTimestamp;
    final String endTime = file.endTimestamp;
    final int duration = int.parse(endTime) - int.parse(startTime);
    final String total = DateTimeHelper.fmtSeconds(duration);
    final String title = DateTimeHelper.fmtTimestamp(
      int.parse(startTime),
      "yyyy-MM-dd HH:mm:ss",
    );
    final String subTitle = "总共$total $fileSize";

    return Container(
      padding: EdgeInsets.only(bottom: 12.w, left: 12.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            selectSN.value == file.sn
                ? "assets/svg/device/selectradio.svg"
                : "assets/svg/device/radio.svg",
            height: 20.w,
            width: 20.w,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ColorUtil.fromHexString("#333333"),
                    fontWeight: FontWeight.w500,
                    fontSize: 16.w,
                    height: 22 / 16,
                  ),
                ),
                Stack(
                  children: [
                    Text(
                      subTitle,
                      style: TextStyle(
                        color: ColorUtil.fromHexString("#333333"),
                        fontSize: 10.w,
                        height: 22 / 16,
                      ),
                    ),
                    if (isUploading && selectSN.value == file.sn)
                      Positioned(
                        top: 2,
                        left: 0,
                        right: 0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static showDialogByChild({
    required Widget child,
    String? title,
    String okText = "confirm",
    String? cancelText,
    Color okTextColor = const Color.fromRGBO(120, 87, 237, 1),
    Color cancelTextColor = const Color.fromRGBO(126, 132, 146, 1),
    Callback? okOntap,
    Callback? cancelOntap,
    bool barrierDismissible = true,
  }) {
    showDialog(
      context: Get.context!,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white,
          title:
              title != null
                  ? Padding(
                    padding: EdgeInsets.only(
                      top: 20.w,
                      left: 20.w,
                      right: 20.w,
                    ),
                    child: Center(
                      child: Text(
                        title.tr,
                      ).mainTitle(fontSize: 18, textAlign: TextAlign.center),
                    ),
                  )
                  : SizedBox(),
          content: Container(
            padding: EdgeInsets.only(
              left: 10.w,
              right: 10.w,
              bottom: 20.w,
              top: title != null ? 12.w : 20.w,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: ColorUtil.fromHexString("#E5E6EB")),
              ),
            ),
            child: child,
          ),
          actionsPadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          titlePadding: EdgeInsets.zero,
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                cancelText != null
                    ? Expanded(
                      child: GestureDetector(
                        onTap:
                            () =>
                                cancelOntap != null
                                    ? cancelOntap()
                                    : Get.back(),
                        child: Container(
                          width: Get.width,
                          height: 44.w,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                            ),
                            border: Border(
                              right: BorderSide(
                                color: ColorUtil.fromHexString("#E5E6EB"),
                                width: 1.w,
                              ),
                            ),
                          ),
                          child: Text(
                            cancelText.tr,
                            style: TextStyle(color: cancelTextColor),
                          ),
                        ),
                      ),
                    )
                    : SizedBox.shrink(),

                Expanded(
                  child: GestureDetector(
                    onTap: okOntap,
                    child: Container(
                      width: Get.width,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        color: Colors.white,
                      ),
                      height: 44.w,
                      alignment: Alignment.center,
                      child: Text(
                        okText.tr,
                        style: TextStyle(color: okTextColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

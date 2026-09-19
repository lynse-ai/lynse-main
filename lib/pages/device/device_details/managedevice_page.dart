import 'package:dting/pages/home/folder_manage/widget/edit_text_widget.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

import 'managedevice_controller.dart';

class ManageDevicePage extends GetView<ManageDeviceController> {
  const ManageDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtil.fromHexString("#F3F4F8"),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Obx(
          () => Container(
            width: Get.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(15.w),
                bottomRight: Radius.circular(15.w),
              ),
              gradient: LinearGradient(
                colors: [
                  ColorUtil.fromHexString("#E5EBF7"),
                  ColorUtil.fromHexString("#FFFFFF"),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.40],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _topAppbar(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.only(
                            bottom: 20.w,
                            left: 24.w,
                            right: 24.w,
                          ),
                          child: Column(
                            children: [
                              Column(
                                children: [
                                  _topImage(),
                                  SizedBox(height: 12.w),
                                  _menu(),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16.w),
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 24.w),
                          width: Get.width,
                          child: Text("General".tr).boldTitle(
                            color: ColorUtil.fromHexString("#7E8492"),
                          ),
                        ),
                        SizedBox(height: 16.w),

                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 24.w),
                          padding: EdgeInsets.symmetric(horizontal: 11.w),
                          decoration: BoxDecoration(
                            color: ColorUtil.fromHexString("#FFFFFF"),
                            borderRadius: BorderRadius.circular(12.w),
                            boxShadow: [
                              BoxShadow(
                                offset: Offset(0, 2),
                                blurRadius: 18,
                                spreadRadius: 0,
                                color: ColorUtil.fromHexString("#000000", 0.08),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _contentRightBackRow(
                                lefttitle: "name".tr,
                                righttitle:
                                    controller.selectDevice.value.deviceName ??
                                    "not set".tr,
                                righttitleColor: ColorUtil.fromHexString(
                                  "#7E8492",
                                ),
                                showRightBack: true,
                                ontap: () {
                                  Get.bottomSheet(
                                    EditTextWidget(
                                      onClick: (bool? val, String editText) {
                                        controller.editDeviceName(editText);
                                      },
                                      needEditText:
                                          controller
                                              .selectDevice
                                              .value
                                              .deviceName ??
                                          "",
                                      title: "editDeviceName",
                                    ),
                                    isScrollControlled: true,
                                  );
                                },
                              ),
                              Divider(
                                color: ColorUtil.fromHexString("#EBECF0"),
                                height: 1.w,
                              ),
                              _copySerialNumber(),
                              Divider(
                                color: ColorUtil.fromHexString("#EBECF0"),
                                height: 1.w,
                              ),
                              Obx(
                                () => _contentRightBackRow(
                                  ontap: () {
                                    controller.handleOtaUpgrade(
                                      controller
                                              .appController
                                              .connectingDevice
                                              .value
                                              .version ??
                                          "",
                                    );
                                    // controller.handleOtaTest();
                                  },
                                  lefttitle: "OTA Update".tr,
                                  righttitle:
                                      controller
                                          .appController
                                          .connectingDevice
                                          .value
                                          .version ??
                                      "",
                                  righttitleColor: ColorUtil.fromHexString(
                                    "#7E8492",
                                  ),
                                ),
                              ),
                              // Divider(
                              //   color: ColorUtil.fromHexString("#EBECF0"),
                              //   height: 1.w,
                              // ),
                              // _contentRightBackRow(
                              //   ontap: () {},
                              //   lefttitle: "Idle shutdown".tr,
                              //   righttitle: "15 分钟",
                              // ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16.w),
                        _unBindDevice(),
                        SizedBox(height: 20.w),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topAppbar() {
    return Container(
      height: 75.w,
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () {
          Get.back();
        },
        child: Row(
          children: [
            Image.asset('assets/images_v3/back.png', width: 24.w, height: 24.w),
          ],
        ),
      ),
    );
  }

  _unBindDevice() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w),
      padding: EdgeInsets.symmetric(horizontal: 11.w),
      decoration: BoxDecoration(
        color: ColorUtil.fromHexString("#FFFFFF"),
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 2),
            blurRadius: 18,
            spreadRadius: 0,
            color: ColorUtil.fromHexString("#000000", 0.08),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // _contentRightBackRow(
          //   lefttitle: "Disconnect",
          //   ontap: () {
          //     controller.disConnectDeviceByUuid();
          //   },
          // ),
          // DividerWidget(spacer: 0),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              DialogHelper.showTipDialog(
                message: 'DisBind',
                title: 'DisBindDevice',
                okText: 'confirm',
                cancelText: "cancel",
                okOntap: () {
                  controller.isBindDevice();
                },
              );
            },
            child: Container(
              height: 50.w,
              alignment: Alignment.centerLeft,
              child: Text(
                // controller.isbind.value ? "解绑" : "重新绑定",
                "DisBind2".tr,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ColorUtil.fromHexString("#409CE9"),
                  fontWeight: FontWeight.w400,
                  fontSize: 16.w,
                  height: 24 / 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _copySerialNumber() {
    return GestureDetector(
      onTap: () {
        controller.copySericalNumber();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 50.w,
        width: Get.width,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("nmber".tr).descText(fontSize: 16),
            SizedBox(width: 12.w),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      controller.selectDevice.value.macAddress ?? "not set",
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ColorUtil.fromHexString("#7E8492"),
                        fontWeight: FontWeight.w400,
                        fontSize: 14.sp,
                        height: 24 / 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.only(left: 5.w),
                    child: Image.asset(
                      color: ColorUtil.fromHexString("#7E8492"),
                      'assets/images_v3/copy2.png',
                      width: 20.w,
                      height: 20.w,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentRightBackRow({
    Callback? ontap,
    required String lefttitle,
    String? leftAssestName,
    Color? lefttitleColor,
    Color? righttitleColor,
    String? righttitle,
    double righttitleSize = 14,
    bool showRightBack = true,
  }) {
    return GestureDetector(
      onTap: ontap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 50.w,
        width: Get.width,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                leftAssestName != null
                    ? Image.asset(leftAssestName, width: 25.w, height: 25.w)
                    : SizedBox(),
                Text(
                  lefttitle.tr,
                ).descText(color: lefttitleColor, fontSize: 16),
              ],
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  righttitle != null
                      ? Expanded(
                        child: Text(
                          righttitle.tr,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: righttitleColor,
                            fontWeight: FontWeight.w400,
                            fontSize: righttitleSize.w,
                            height: 24 / 14,
                          ),
                        ),
                      )
                      : SizedBox(),
                  showRightBack
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
      ),
    );
  }

  Widget _menu() {
    return Obx(
      () => Container(
        width: Get.width,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15.r),
          color: ColorUtil.fromHexString("#F8F9FB"),
        ),
        child: Column(
          children: [
            _contentRightBackRow(
              lefttitle: 'BatteryLevel',
              leftAssestName:
                  controller.appController.deviceDetailBatteryIconUrl.value,
              righttitle:
                  "${controller.appController.showBatteryString.value}%", // controller.appController.batteryString.value,
              showRightBack: false,
              righttitleSize: 16,
              lefttitleColor: ColorUtil.fromHexString("#898E9B"),
            ),
            DividerWidget(spacer: 0),
            _contentRightBackRow(
              lefttitle: 'RecordingMode',
              leftAssestName:
                  controller.appController.meetingStatus.value == 0
                      ? "assets/images_v3/detail-device-meeting.png"
                      : "assets/images_v3/detail-device-calling.png",
              righttitle:
                  controller.appController.meetingStatus.value == 0
                      ? "Meeting mode".tr
                      : "Call mode".tr,
              showRightBack: false,
              righttitleSize: 16,
              lefttitleColor: ColorUtil.fromHexString("#898E9B"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topImage() {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            controller.selectDevice.value.deviceName ?? "",
          ).boldTitle(fontSize: 24),
          SizedBox(width: 12.w),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 24.w,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  color: ColorUtil.fromHexString("#EDFEF3"),
                  borderRadius: BorderRadius.circular(10.w),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 5.w,
                      height: 5.w,
                      decoration: BoxDecoration(
                        color: ColorUtil.fromHexString("#17B36A"),
                        borderRadius: BorderRadius.circular(10.w),
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text("Connected".tr).boldTitle(
                      color: ColorUtil.fromHexString("#17B36A"),
                      fontSize: 13,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Image.asset(
            'assets/images_v3/device2.png',
            fit: BoxFit.fitHeight,
            height: 200.w,
          ),
        ],
      ),
    );
  }
}

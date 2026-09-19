import 'package:dting/model/device_model/deviceinfo_model.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/bluetooth_utils.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/utils/permission_helper.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class TopSheetByDevice extends GetView {
  const TopSheetByDevice({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<DtingStore>();
    return Container(
      width: Get.width,
      padding: _getContainerPadding(),
      decoration: _getContainerDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTitle(),
          SizedBox(height: 20.w),
          Column(
            children:
                appController.scanDeviceList
                    .where(
                      (device) =>
                          appController.connectingDevice.value.macAddress !=
                              null &&
                          appController.connectingDevice.value.macAddress ==
                              device.macAddress,
                    )
                    .map((device) => _deviceItem(appController, device))
                    .toList(),
          ),
          _buildAddDeviceButton(),
        ],
      ),
    );
  }

  EdgeInsets _getContainerPadding() {
    return EdgeInsets.only(left: 20.w, right: 20.w, top: 50.w, bottom: 20.w);
  }

  BoxDecoration _getContainerDecoration() {
    return BoxDecoration(
      color: ColorUtil.fromHexString("#FFFFFF"),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(15.r),
        bottomRight: Radius.circular(15.r),
      ),
    );
  }

  Widget _buildTitle() {
    return GestureDetector(
      onTap: () {
        Get.back();
      },
      child: Row(
        children: [
          Text(
            "connectDevice".tr,
          ).mainTitle(color: ColorUtil.fromHexString("#161616"), fontSize: 15),
          SizedBox(width: 5.w),
          Image.asset(
            'assets/images_v3/chevron-topt.png',
            height: 18.w,
            width: 18.w,
          ),
        ],
      ),
    );
  }

  Widget _buildAddDeviceButton() {
    return GestureDetector(
      onTap: () async {
        //添加设备
        Get.back();
        // 检查蓝牙权限
        bool hasPermission =
            await PermissionsHelper.requestBluetoothPermissions();
        if (hasPermission) {
          NavigationUtils.toBootstrapOperation();
        } else {
          DialogHelper.showDialogByChild(
            title: "Permission",
            child: Text("settingOpenBlue".tr, textAlign: TextAlign.center),
            cancelText: "cancel",
            okText: "Settings",
            okOntap: () {
              NavigationUtils.back();
              openAppSettings();
            },
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(top: 8.w),
        child: Row(
          children: [
            Image.asset(
              'assets/images_v3/add-device.png',
              height: 28.w,
              width: 28.w,
            ),
            SizedBox(width: 10.w),
            Text(
              "AddDtingDevice".tr,
            ).descText(color: ColorUtil.fromHexString("#161616"), fontSize: 12),
          ],
        ),
      ),
    );
  }

  Widget _deviceItem(DtingStore appController, DeviceInfoModel device) {
    // var existDevice = appController.bindDeviceList.firstWhereOrNull(
    //   (item) => item.macAddress == device.macAddress,
    // );
    // if (existDevice != null) {
    //   device.deviceName = existDevice.deviceName;
    // }
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            if (appController.connectingDevice.value.macAddress != null &&
                appController.connectingDevice.value.macAddress ==
                    device.macAddress) {
              Get.back();
              NavigationUtils.toManageDevice(
                appController.connectingDevice.value,
              );
            } else {
              //切换连接
              if (await BluetoothUtils.instance.isBluetoothEnabled()) {
                print("✅ 蓝牙已打开");
                await EasyLoading.show();
                try {
                  if (appController.connectingDevice.value.macAddress == null) {
                    // 没有连接设备，直接连接
                    await appController.isBind(deviceUuid: device);
                  } else {
                    // 有连接设备，先断开
                    appController.stopRecord();
                    await NvEasyPlugin().startDisconnect(
                      appController.connectingDevice.value.macAddress!,
                    );

                    // 再连接新设备
                    await appController.isBind(deviceUuid: device);
                  }
                  Get.back();
                } finally {
                  await EasyLoading.dismiss(); // 在 isBind 结束后才关 loading
                }
              } else {
                print("❌ 蓝牙未打开");
                DialogHelper.showToastDialog("BluePermissions");
              }
            }
          },
          child: Container(
            width: double.infinity,
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: buildDeviceInfo(appController, device)),
                _buildArrowIcon(),
              ],
            ),
          ),
        ),
        DividerWidget(spacer: 10),
      ],
    );
  }

  static Widget buildDeviceInfo(
    DtingStore appController,
    DeviceInfoModel device,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildAvatarBackground(appController),
        SizedBox(width: 5.w),
        _buildDeviceDetails(appController, device),
      ],
    );
  }

  static Widget _buildAvatarBackground(DtingStore appController) {
    return Stack(
      clipBehavior: Clip.none, // 允许溢出
      children: [
        // 底层：圆形背景 + 设备图
        ClipOval(
          child: Container(
            width: 28.w,
            height: 28.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              color: ColorUtil.fromHexString("#E1E6EA"),
            ),
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.w),
            child: Image.asset(
              'assets/images_v3/device2.png',
              height: 23.w,
              width: 23.w,
            ),
          ),
        ),
        // // 右下角覆盖：紫色小圆图标
        // if (appController.connectingDevice.value.uuid == null ||
        //     appController.connectingDevice.value.uuid == "")
        //   Positioned(
        //     bottom: -2,
        //     right: -2,
        //     child: Image.asset(
        //       'assets/images_v3/disConnect.png',
        //       height: 16.w,
        //       width: 16.w,
        //     ),
        //   ),
      ],
    );
    //  Container(
    //   width: 28.w,
    //   height: 28.w,
    //   decoration: BoxDecoration(
    //     borderRadius: BorderRadius.circular(12.r),
    //     color: ColorUtil.fromHexString("#E1E6EA"),
    //   ),
    //   padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.w),
    //   child: Image.asset(
    //     'assets/images_v3/device2.png',
    //     height: 23.w,
    //     width: 23.w,
    //   ),
    // );
  }

  static Widget _buildDeviceDetails(
    DtingStore appController,
    DeviceInfoModel device,
  ) {
    return Obx(
      () => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildDeviceName(appController, device),
          SizedBox(width: 10.w),
          _buildBatteryIcon(appController, device),
        ],
      ),
    );
  }

  static Widget _buildDeviceName(
    DtingStore appController,
    DeviceInfoModel device,
  ) {
    final deviceName = device.deviceName ?? "Unknown";

    return Text(deviceName).descText(
      fontSize: 12,
      color: ColorUtil.fromHexString("#161616"),
      overflow: TextOverflow.ellipsis,
    );
  }

  static Widget _buildBatteryIcon(
    DtingStore appController,
    DeviceInfoModel device,
  ) {
    Widget batteryIcon =
        appController.connectingDevice.value.macAddress != null &&
                appController.connectingDevice.value.macAddress ==
                    device.macAddress
            ? Image.asset(appController.batteryIconUrl.value, height: 20.w)
            : SizedBox();
    return batteryIcon;
  }

  Widget _buildArrowIcon() {
    return Container(
      padding: EdgeInsets.only(left: 10.w),
      child: Image.asset(
        'assets/images_v3/arrow-right.png',
        width: 24.w,
        height: 24.w,
      ),
    );
  }
}

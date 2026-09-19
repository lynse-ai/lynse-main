import 'package:dting/model/device_model/deviceinfo_model.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/nodata_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'search_device_controller.dart';

class SearchDevicePage extends GetView<SearchDeviceController> {
  const SearchDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtil.fromHexString("#F2F2F2"),
      appBar: AppBarWidgets.getAppBar(
        backgroundColor: ColorUtil.fromHexString("#F2F2F2"),
        title: "searchDevice",
        textAlign: TextAlign.center,
      ),
      body: Obx(
        () => Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.w),
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child:
                controller.appController.scanDeviceList.isNotEmpty
                    ? Column(
                      children:
                          controller.appController.scanDeviceList
                              .map((device) => _deviceDetail(device))
                              .toList(),
                    )
                    : NoDataWidget(),
          ),
        ),
      ),
    );
  }

  Widget _deviceDetail(DeviceInfoModel device) {
    // var existDevice = controller.appController.bindDeviceList.firstWhereOrNull(
    //   (item) => item.macAddress == device.macAddress,
    // );
    // if (existDevice != null) {
    //   device.deviceName = existDevice.deviceName;
    // }

    return Obx(
      () => Container(
        width: 327.w,
        margin: EdgeInsets.only(bottom: 30.w),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: ColorUtil.fromHexString("#FFFFFF"),
          borderRadius: BorderRadius.circular(42.w),
          border: Border.all(
            color: ColorUtil.fromHexString("#E7E9EC"),
            width: 1.w,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                if (controller
                            .appController
                            .connectingDevice
                            .value
                            .macAddress !=
                        null &&
                    controller
                            .appController
                            .connectingDevice
                            .value
                            .macAddress ==
                        device.macAddress) {
                  NavigationUtils.toManageDevice(device);
                } else {
                  DialogHelper.showToastDialog("fistConnectDevice");
                }
              },
              child: Column(
                children: [
                  Text(device.deviceName ?? "").mainTitle(fontSize: 20),
                  SizedBox(height: 6.w),
                  Text(
                    "Mac：${device.macAddress}",
                  ).descText(color: ColorUtil.fromHexString("#5B5E68")),

                  if (controller
                              .appController
                              .connectingDevice
                              .value
                              .macAddress !=
                          null &&
                      controller
                              .appController
                              .connectingDevice
                              .value
                              .macAddress ==
                          device.macAddress &&
                      controller.appController.connectingDevice.value.version !=
                          null &&
                      controller.appController.connectingDevice.value.version !=
                          "")
                    Container(
                      padding: EdgeInsets.only(top: 3.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${"otaVersion".tr}：",
                          ).descText(color: ColorUtil.fromHexString("#5B5E68")),
                          Text(
                            controller
                                .appController
                                .connectingDevice
                                .value
                                .version!,
                          ).descText(color: ColorUtil.fromHexString("#5B5E68")),
                        ],
                      ),
                    ),
                  if (controller
                              .appController
                              .connectingDevice
                              .value
                              .macAddress !=
                          null &&
                      controller
                              .appController
                              .connectingDevice
                              .value
                              .macAddress ==
                          device.macAddress)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 24.w,
                          alignment: Alignment.center,
                          margin: EdgeInsets.symmetric(vertical: 10.w),
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
                              SizedBox(width: 5.w),
                              Image.asset(
                                controller.appController.batteryIconUrl.value,
                                width: 20.w,
                                height: 20.w,
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                "${controller.appController.showBatteryString}%",
                              ).descText(
                                fontSize: 10,
                                color: ColorUtil.fromHexString("#5B5E68"),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  Image.asset(
                    'assets/images_v3/device2.png',
                    height: 120.w,
                    width: 120.w,
                  ),
                ],
              ),
            ),

            SizedBox(height: 15.w),
            GestureDetector(
              onTap: () {
                controller.currentSelectDevice.value = device;
                controller.connectingDevice();
              },
              child: Container(
                height: 48.w,
                width: Get.width,
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                margin: EdgeInsets.symmetric(horizontal: 24.w),
                decoration: BoxDecoration(
                  color: ColorUtil.fromHexString("#D0D4DD"),
                  borderRadius: BorderRadius.circular(50.w),
                ),
                child: Text(
                  controller.appController.connectingDevice.value.macAddress !=
                              null &&
                          controller
                                  .appController
                                  .connectingDevice
                                  .value
                                  .macAddress ==
                              device.macAddress
                      ? "DisBind2".tr
                      : "ConnectingDevice".tr,
                ).mainTitle(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

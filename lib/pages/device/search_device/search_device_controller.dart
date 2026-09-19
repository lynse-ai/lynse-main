import 'package:dting/model/device_model/deviceinfo_model.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';
import 'package:dting/service/device_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/bluetooth_utils.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class SearchDeviceController extends GetxController {
  var appController = Get.find<DtingStore>();
  var currentSelectDevice = DeviceInfoModel.genDefault().obs; //当前选择的硬件

  //判断权限之后才能添加设备
  Future<void> connectingDevice() async {
    if (appController.connectingDevice.value.macAddress != null &&
        appController.connectingDevice.value.macAddress ==
            currentSelectDevice.value.macAddress) {
      //解绑
      DialogHelper.showTipDialog(
        message: 'DisBind',
        title: 'DisBindDevice',
        okText: 'confirm',
        cancelText: "cancel",
        okOntap: () {
          isBindDevice();
        },
      );
    } else {
      //开始连接
      if (await BluetoothUtils.instance.isBluetoothEnabled()) {
        print("✅ 蓝牙已打开");
        await EasyLoading.show();
        try {
          if (appController.connectingDevice.value.macAddress == null) {
            // 没有连接设备，直接连接
            await appController.isBind(deviceUuid: currentSelectDevice.value);
          } else {
            // 有连接设备，先断开
            appController.stopRecord();
            await NvEasyPlugin().startDisconnect(
              appController.connectingDevice.value.macAddress!,
            );

            // 再连接新设备
            await appController.isBind(deviceUuid: currentSelectDevice.value);
          }
        } finally {
          await EasyLoading.dismiss(); // 在 isBind 结束后才关 loading
        }
      } else {
        print("❌ 蓝牙未打开");
        DialogHelper.showToastDialog("BluePermissions");
      }
    }
  }

  //解绑设备
  Future<void> isBindDevice() async {
    Get.back();
    if (appController.connectingDevice.value.macAddress != null) {
      EasyLoading.show(status: '${"Unbinding".tr}...');
      try {
        // 原生断开绑定
        await NvEasyPlugin().bindDevice(false);
        // 数据库断开绑定
        await DeviceService.unBindDevice(
          macAddress: appController.connectingDevice.value.macAddress!,
        );
        LocalDataBase().basicBox!.put(
          "didConnect",
          null,
        ); // 解绑数据刷新缓存        // 断开连接
        await NvEasyPlugin().startDisconnect(
          appController.connectingDevice.value.macAddress!,
        );
      } finally {
        EasyLoading.dismiss();
      }
    } else {
      DialogHelper.showToastDialog("fistConnectDevice");
    }
  }
}

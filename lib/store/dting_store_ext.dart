import 'dart:io';

import 'package:dting/config/config.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';
import 'package:dting/service/permission_service.dart';
import 'package:dting/utils/device_utils.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/utils/logger_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:get/get.dart';

import '../utils/bluetooth_utils.dart';
import 'dting_store.dart';

extension DtingStoreExt on DtingStore {
  /// 开始扫描
  Future<void> starScan() async {
    // 防止重复扫描
    if (isScanning.value || isRequestingPermission.value) {
      LoggerUtils.d('正在扫描或请求权限中，跳过重复调用');
      return;
    }
    //判断有没有登录
    bool isLogin = false;
    if (LocalDataBase().basicBox!.get("islogin", defaultValue: "false") ==
        "true") {
      isLogin = true;
    }
    // 跳过登录的临时联调模式下同样放行扫描（与 Config.debugSkipLogin 同步恢复）
    if (!isLogin && !Config.debugSkipLogin) {
      print('还没有登录，不能搜索蓝牙设备');
      return;
    }
    isScanning.value = true;
    LoggerUtils.d('starScan DT');
    try {
      final checkBluetoothPermission =
          await PermissionService.instance.checkBluetoothPermission();
      if (checkBluetoothPermission) {
        LoggerUtils.d('checkBluetoothPermission DT');
        handleBlueOnOff();
      } else {
        isRequestingPermission.value = true;
        var bluetooth = LocalDataBase().basicBox!.get("bluetoothPermission");
        var hasGranted =
            await PermissionService.instance.requestBluetoothPermissions();
        LoggerUtils.d('requestBluetoothPermissions DT');
        if (hasGranted) {
          LocalDataBase().basicBox!.put("bluetoothPermission", true);
          handleBlueOnOff();
        } else {
          LocalDataBase().basicBox!.put("bluetoothPermission", false);
          // if (bluetooth == null) {
          //   DialogHelper.showToastDialog('blueSearchAndConnectTip');
          // }
        }
        isRequestingPermission.value = false;
      }
    } finally {
      isScanning.value = false;
    }
  }

  //处理蓝牙开关逻辑
  Future<void> handleBlueOnOff() async {
    var isBluetoothEnable = await BluetoothUtils.instance.isBluetoothEnabled();
    if (isBluetoothEnable) {
      final sdkVersion =
          await PermissionService.instance.getAndroidSdkVersion();
      //如果是Android 并且是华为手机或者Android 11 以下，需要位置开关打开
      if (Platform.isAndroid &&
          (await DeviceUtils.instance.isHuaweiPhone() || sdkVersion < 31)) {
        if (await BluetoothUtils.instance.isLocationEnabled()) {
          // 开始扫描
          NvEasyPlugin().startScan();
        } else {
          BluetoothUtils.instance.requestLocationService().then((value) {
            if (value) {
              NvEasyPlugin().startScan();
            } else {
              DialogHelper.showToastDialog('addressRequest');
            }
          });
        }
      } else {
        NvEasyPlugin().startScan();
      }
    } else {
      // DialogHelper.showToastDialog('蓝牙未开启');
      LoggerUtils.d('handleBlueOnOff 蓝牙未开启 DT');
      DialogHelper.showTipDialog(
        message: 'addressRequest',
        title: 'Permission',
        okText: 'confirm',
        okOntap: () {
          Get.back();
          BluetoothUtils.instance.enableBluetooth().then((success) {
            if (success) {
              NvEasyPlugin().startScan();
            } else {
              DialogHelper.showToastDialog('BluePermissionsOpenFail');
            }
          });
        },
      );
    }
  }
}

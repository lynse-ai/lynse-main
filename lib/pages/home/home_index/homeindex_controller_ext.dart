import 'dart:io';

import 'package:dting/service/permission_service.dart';
import 'package:dting/utils/bluetooth_utils.dart';
import 'package:dting/utils/device_utils.dart';
import 'package:dting/utils/logger_utils.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

import 'homeindex_controller.dart';

/// HomeIndexController扩展
///
/// 扩展主页的具体实现
extension HomeIndexControllerExt on HomeIndexController {
  //检查是否有蓝牙权限了
  Future<bool> checkBlueToothPermission() async {
    return await PermissionService.instance.checkBluetoothPermission();
  }

  //请求蓝牙权限
  Future<bool> requestBlueToothPermission() async {
    return await PermissionService.instance.requestBluetoothPermissions();
  }

  // 判断蓝牙是否有打开
  Future<bool> checkBlueToothOpen() async {
    return await BluetoothUtils.instance.isBluetoothEnabled();
  }

  //处理添加设备逻辑
  Future<void> handleAddDevice() async {
    checkBlueToothPermission().then((value) async {
      if (value) {
        await handleBlueOnOff();
      } else {
        //请求前弹窗提示权限说明
        showPermissionDialog();
      }
    });
  }

  Future<void> showPermissionDialog() async {
    var permissionMessage = 'blueRequest';
    if (Platform.isAndroid) {
      final sdkVersion =
          await PermissionService.instance.getAndroidSdkVersion();
      if (sdkVersion >= 31) {
        if (await DeviceUtils.instance.isHuaweiPhone()) {
          // Android 12+ 需要扫描和连接权限
          permissionMessage = 'addressRequest';
        } else {
          permissionMessage = 'blueRequest';
        }
      } else {
        permissionMessage = 'addressRequest';
      }
    }
    DialogHelper.showTipDialog(
      message: permissionMessage,
      title: 'Permission',
      okText: 'confirm',
      okOntap: () {
        Get.back();
        requestBlueToothPermission().then((value) {
          if (value) {
            handleBlueOnOff();
          } else {
            DialogHelper.showToastDialog('blueNotOpen');
          }
        });
      },
    );
  }

  //处理蓝牙开关逻辑
  Future<void> handleBlueOnOff() async {
    if (await checkBlueToothOpen()) {
      final sdkVersion =
          await PermissionService.instance.getAndroidSdkVersion();
      //如果是Android 并且是华为手机或者Android 11 以下，需要位置开关打开
      if (Platform.isAndroid &&
          (await DeviceUtils.instance.isHuaweiPhone() || sdkVersion < 31)) {
        if (await BluetoothUtils.instance.isLocationEnabled()) {
          NavigationUtils.toBootstrapOperation();
        } else {
          BluetoothUtils.instance.requestLocationService().then((value) {
            if (value) {
              NavigationUtils.toBootstrapOperation();
            } else {
              DialogHelper.showToastDialog('addressOpenRequest');
            }
          });
        }
      } else {
        NavigationUtils.toBootstrapOperation();
      }
    } else {
      // DialogHelper.showToastDialog('蓝牙未开启');
      LoggerUtils.d('handleBlueOnOff 蓝牙未开启 HC');
      if (Platform.isIOS) {
        // permission_handler
        DialogHelper.showToastDialog("BluePermissionsBySearch");
        return;
      }
      BluetoothUtils.instance.enableBluetooth().then((success) {
        if (success) {
          NavigationUtils.toBootstrapOperation();
        } else {
          DialogHelper.showToastDialog('BluePermissionsOpenFail');
        }
      });
    }
  }

  void checkBluetooth() async {
    var state = await FlutterBluePlus.adapterState.first;
    if (state == BluetoothAdapterState.on) {
      print("蓝牙已开启");
    } else {
      print("蓝牙未开启");
    }
  }
}

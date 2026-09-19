import 'dart:io';

import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsHelper {
  PermissionsHelper._();
  static Future<bool> requestMicrophonePermissions() async {
    var status = await Permission.microphone.status;
    if (status.isPermanentlyDenied) {
      DialogHelper.showDialogByChild(
        title: "Permission",
        child: Text("deniedTip".tr, textAlign: TextAlign.center),
        cancelText: "cancel",
        okText: "Settings",
        okOntap: () {
          NavigationUtils.back();
          openAppSettings();
        },
      );
      return false;
    } else {
      if (status.isGranted) {
        return true;
      } else {
        var result = await Permission.microphone.request();
        return result.isGranted;
      }
    }
  }

  static bool isIOS() {
    return Platform.isIOS;
  }

  static Future<bool> requestBluetoothPermissions() async {
    // 请求蓝牙权限

    var bluetoothStatus = await Permission.bluetooth.request();

    if (bluetoothStatus.isGranted) {
      return true;
    } else {
      return false;
    }
  }
}

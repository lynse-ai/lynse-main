import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

/// 权限枚举
enum PermissionEnum {
  camera,
  microphone,
  storage,
  location,
  locationWhenInUse,
  locationAlways,
  photos,
  contacts,
  phone,
  sms,
  notification,
  bluetooth,
  bluetoothScan,
  bluetoothAdvertise,
  bluetoothConnect,
}

/// 权限枚举扩展
extension PermissionEnumExtension on PermissionEnum {
  /// 获取对应的Permission对象
  Permission get permission {
    switch (this) {
      case PermissionEnum.camera:
        return Permission.camera;
      case PermissionEnum.microphone:
        return Permission.microphone;
      case PermissionEnum.storage:
        return Permission.storage;
      case PermissionEnum.location:
        return Permission.location;
      case PermissionEnum.locationWhenInUse:
        return Permission.locationWhenInUse;
      case PermissionEnum.locationAlways:
        return Permission.locationAlways;
      case PermissionEnum.photos:
        return Permission.photos;
      case PermissionEnum.contacts:
        return Permission.contacts;
      case PermissionEnum.phone:
        return Permission.phone;
      case PermissionEnum.sms:
        return Permission.sms;
      case PermissionEnum.notification:
        return Permission.notification;
      case PermissionEnum.bluetooth:
        return Permission.bluetooth;
      case PermissionEnum.bluetoothScan:
        return Permission.bluetoothScan;
      case PermissionEnum.bluetoothAdvertise:
        return Permission.bluetoothAdvertise;
      case PermissionEnum.bluetoothConnect:
        return Permission.bluetoothConnect;
    }
  }

  /// 获取权限名称
  String get name {
    switch (this) {
      case PermissionEnum.camera:
        return 'camera'.tr;
      case PermissionEnum.microphone:
        return 'microphone'.tr;
      case PermissionEnum.storage:
        return 'storage'.tr;
      case PermissionEnum.location:
        return 'location'.tr;
      case PermissionEnum.locationWhenInUse:
        return 'locationWhenInUse'.tr;
      case PermissionEnum.locationAlways:
        return 'locationAlways'.tr;
      case PermissionEnum.photos:
        return 'gallery'.tr;
      case PermissionEnum.contacts:
        return 'contacts'.tr;
      case PermissionEnum.phone:
        return 'phonePermission'.tr;
      case PermissionEnum.sms:
        return 'sms'.tr;
      case PermissionEnum.notification:
        return 'notification'.tr;
      case PermissionEnum.bluetooth:
        return 'bluetooth'.tr;
      case PermissionEnum.bluetoothScan:
        return 'bluetoothScan'.tr;
      case PermissionEnum.bluetoothAdvertise:
        return 'bluetoothAdvertise'.tr;
      case PermissionEnum.bluetoothConnect:
        return 'bluetoothConnect'.tr;
    }
  }
}

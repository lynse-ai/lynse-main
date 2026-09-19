import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class DeviceUtils {
  static final DeviceUtils _instance = DeviceUtils._internal();

  factory DeviceUtils() => _instance;

  static DeviceUtils get instance => _instance;

  DeviceUtils._internal();

  /// 判断是否是华为设备
  Future<bool> isHuaweiPhone() async {
    if (!Platform.isAndroid) return false;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    final manufacturer = androidInfo.manufacturer.toLowerCase();
    final brand = androidInfo.brand.toLowerCase();

    return manufacturer.contains('huawei') || brand.contains('huawei');
  }
}

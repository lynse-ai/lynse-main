import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:dting/utils/logger_utils.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:location/location.dart';

class BluetoothUtils {
  static final BluetoothUtils _instance = BluetoothUtils._internal();

  factory BluetoothUtils() => _instance;

  static BluetoothUtils get instance => _instance;

  BluetoothUtils._internal();

  Stream<BluetoothAdapterState> get bluetoothStateStream =>
      FlutterBluePlus.adapterState;

  static final Location location = Location();

  //判断蓝牙开关是否开启
  Future<bool> isBluetoothEnabled() async {
    // iOS 蓝牙状态需要等待蓝牙状态更新
    if (Platform.isIOS) {
      if (await FlutterBluePlus.adapterState.first ==
          BluetoothAdapterState.unknown) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    // 监听蓝牙状态变化
    BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
    // 检查蓝牙状态
    return state == BluetoothAdapterState.on;
  }

  // 打开蓝牙并监听结果
  Future<bool> enableBluetooth({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      LoggerUtils.d('enableBluetooth 开启蓝牙');
      await FlutterBluePlus.turnOn();
      final state = await FlutterBluePlus.adapterState.firstWhere(
        (s) => s == BluetoothAdapterState.on,
        orElse: () => BluetoothAdapterState.off,
      );
      return state == BluetoothAdapterState.on;
    } catch (e) {
      print("开启蓝牙失败: $e");
      return false;
    }
  }

  //判断手机的位置开关是否打开
  Future<bool> isLocationEnabled() async {
    try {
      final status = await location.serviceEnabled();
      if (!status) {
        // 双重检查确保状态准确
        return await location.serviceEnabled();
      }
      return status;
    } catch (e) {
      // 使用更基础的检查方法作为备选
      return false;
    }
  }

  // 请求开启位置服务
  Future<bool> requestLocationService() async {
    try {
      if (!await isLocationEnabled()) {
        final result = await location.requestService();
        // 返回前再次确认服务状态
        return result || await isLocationEnabled();
      }
      return true;
    } catch (e) {
      print('请求位置服务失败: $e');
      // 备选方案：直接打开系统位置设置
      await AppSettings.openAppSettings(type: AppSettingsType.location);
      return false;
    }
  }
}

import 'dart:async';
import 'dart:io';
import 'package:dting/enums/permission_enum.dart';
import 'package:dting/utils/bluetooth_utils.dart';
import 'package:dting/utils/device_utils.dart';
import 'package:dting/utils/logger_utils.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// 权限服务
class PermissionService {
  static PermissionService? _instance;
  static PermissionService get instance => _instance ??= PermissionService._();

  PermissionService._();

  /// 设备信息插件实例
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// 缓存的Android SDK版本
  int? _androidSdkVersion;

  /// 获取Android SDK版本
  Future<int> getAndroidSdkVersion() async {
    if (_androidSdkVersion != null) {
      return _androidSdkVersion!;
    }

    if (Platform.isAndroid) {
      try {
        final androidInfo = await _deviceInfo.androidInfo;
        _androidSdkVersion = androidInfo.version.sdkInt;
        LoggerUtils.d('Android SDK版本: $_androidSdkVersion');
        return _androidSdkVersion!;
      } catch (e) {
        LoggerUtils.e('获取Android版本失败', e);
        // 默认返回较新版本，确保请求新权限
        _androidSdkVersion = 33;
        return _androidSdkVersion!;
      }
    }

    return 0; // 非Android平台
  }

  /// 请求单个权限
  Future<bool> requestPermission(
    PermissionEnum permissionEnum, {
    String? customTip,
  }) async {
    try {
      final permission = permissionEnum.permission;

      // 检查当前权限状态
      final status = await permission.status;

      if (status.isGranted) {
        LoggerUtils.d('权限已授予: ${permissionEnum.name}');
        return true;
      }

      if (status.isDenied) {
        // 显示自定义权限请求提示
        if (Platform.isAndroid) {
          // 检查是否已显示过提示
          final hasShownHint =
              await LocalDataBase().basicBox?.get(
                "hasShown\${permissionEnum.name}PermissionHint",
              ) ??
              false;
          if (!hasShownHint) {
            final shouldContinue = await showPermissionRequestTip(
              permissionEnum,
              customTip,
            );
            if (!shouldContinue) {
              return false;
            }
            // 记录已显示过提示
            await LocalDataBase().basicBox?.put(
              "hasShown\${permissionEnum.name}PermissionHint",
              true,
            );
          }
        }

        // 请求权限
        final result = await permission.request();

        if (result.isGranted) {
          LoggerUtils.d('权限请求成功: ${permissionEnum.name}');
          return true;
        } else if (result.isPermanentlyDenied) {
          LoggerUtils.w('权限被永久拒绝: ${permissionEnum.name}');
          await _showPermissionDeniedDialog(permissionEnum);
          return false;
        } else {
          LoggerUtils.w('权限请求被拒绝: ${permissionEnum.name}');
          return false;
        }
      }

      if (status.isPermanentlyDenied) {
        LoggerUtils.w('权限已被永久拒绝: ${permissionEnum.name}');
        await _showPermissionDeniedDialog(permissionEnum);
        return false;
      }

      return false;
    } catch (e) {
      LoggerUtils.e('请求权限时发生错误: ${permissionEnum.name}', e);
      return false;
    }
  }

  /// 请求多个权限
  Future<Map<PermissionEnum, bool>> requestPermissions(
    List<PermissionEnum> permissions, {
    Map<PermissionEnum, String>? customTips,
  }) async {
    final Map<PermissionEnum, bool> results = {};

    try {
      // 构建权限映射
      final Map<Permission, PermissionEnum> permissionMap = {};
      for (final permissionEnum in permissions) {
        permissionMap[permissionEnum.permission] = permissionEnum;
      }

      // 在批量请求权限前，显示自定义提示
      for (final permissionEnum in permissions) {
        if (Platform.isAndroid) {
          final hasShownHint =
              await LocalDataBase().basicBox?.get(
                "hasShown\${permissionEnum.name}PermissionHint",
              ) ??
              false;
          if (!hasShownHint) {
            final shouldContinue = await showPermissionRequestTip(
              permissionEnum,
              customTips?[permissionEnum],
            );
            if (!shouldContinue) {
              // 用户取消，不请求此权限
              results[permissionEnum] = false;
              permissions.remove(permissionEnum);
              continue;
            }
            // 记录已显示过提示
            await LocalDataBase().basicBox?.put(
              "hasShown\${permissionEnum.name}PermissionHint",
              true,
            );
          }
        }
      }

      if (permissions.isEmpty) {
        return results;
      }

      // 重建权限映射，因为可能有用户取消的权限
      final Map<Permission, PermissionEnum> updatedPermissionMap = {};
      for (final permissionEnum in permissions) {
        updatedPermissionMap[permissionEnum.permission] = permissionEnum;
      }

      // 批量请求权限
      final statuses = await updatedPermissionMap.keys.toList().request();

      // 处理结果
      for (final entry in statuses.entries) {
        final permissionEnum = updatedPermissionMap[entry.key]!;
        final status = entry.value;

        if (status.isGranted) {
          results[permissionEnum] = true;
          LoggerUtils.d('权限请求成功: ${permissionEnum.name}');
        } else {
          results[permissionEnum] = false;
          if (status.isPermanentlyDenied) {
            // LoggerUtils.w('权限被永久拒绝: ${permissionEnum.name}');
          } else {
            // LoggerUtils.w('权限请求被拒绝: ${permissionEnum.name}');
          }
        }
      }

      // 检查是否有被永久拒绝的权限
      final permanentlyDeniedPermissions =
          results.entries
              .where((entry) => !entry.value)
              .map((entry) => entry.key)
              .where(
                (permission) =>
                    statuses[permission.permission]?.isPermanentlyDenied ==
                    true,
              )
              .toList();

      if (permanentlyDeniedPermissions.isNotEmpty) {
        await _showMultiplePermissionsDeniedDialog(
          permanentlyDeniedPermissions,
        );
      }
    } catch (e) {
      LoggerUtils.e('批量请求权限时发生错误', e);
      // 如果批量请求失败，逐个请求
      for (final permission in permissions) {
        results[permission] = await requestPermission(
          permission,
          customTip: customTips?[permission],
        );
      }
    }

    return results;
  }

  /// 检查权限状态
  Future<bool> checkPermission(PermissionEnum permissionEnum) async {
    try {
      final status = await permissionEnum.permission.status;
      return status.isGranted;
    } catch (e) {
      LoggerUtils.e('检查权限状态时发生错误: ${permissionEnum.name}', e);
      return false;
    }
  }

  /// 检查多个权限状态
  Future<Map<PermissionEnum, bool>> checkPermissions(
    List<PermissionEnum> permissions,
  ) async {
    final Map<PermissionEnum, bool> results = {};

    for (final permission in permissions) {
      results[permission] = await checkPermission(permission);
    }

    return results;
  }

  /// 打开应用设置页面
  Future<bool> openAppSettingsPermission() async {
    try {
      return await openAppSettings();
    } catch (e) {
      LoggerUtils.e('打开应用设置页面失败', e);
      return false;
    }
  }

  /// 获取Android版本适配的存储权限
  List<PermissionEnum> getStoragePermissions() {
    if (Platform.isAndroid) {
      // Android 13 (API 33) 及以上版本使用新的权限模型
      // 这里简化处理，实际项目中可能需要更复杂的版本判断
      return [PermissionEnum.storage, PermissionEnum.photos];
    }
    return [PermissionEnum.storage];
  }

  /// 获取位置权限（根据需求选择精确度）
  List<PermissionEnum> getLocationPermissions({bool needAlways = false}) {
    if (needAlways) {
      return [PermissionEnum.locationWhenInUse, PermissionEnum.locationAlways];
    }
    return [PermissionEnum.locationWhenInUse];
  }

  /// 获取蓝牙权限（根据平台和Android版本）
  Future<List<PermissionEnum>> getBluetoothPermissions() async {
    if (Platform.isIOS) {
      // iOS只需要基础蓝牙权限
      return [PermissionEnum.bluetooth];
    }

    if (Platform.isAndroid) {
      final sdkVersion = await getAndroidSdkVersion();

      if (sdkVersion >= 31) {
        // Android 12 (API 31) 及以上版本需要新的蓝牙权限
        LoggerUtils.d('Android 12+，使用新蓝牙权限模型');
        //如果是华为手机，需要定位权限
        if (await DeviceUtils.instance.isHuaweiPhone()) {
          return [
            PermissionEnum.bluetoothScan,
            PermissionEnum.bluetoothConnect,
            PermissionEnum.location,
          ];
        } else {
          return [
            PermissionEnum.bluetoothScan,
            PermissionEnum.bluetoothConnect,
            PermissionEnum.location,
          ];
        }
      } else {
        // Android 11 及以下版本使用传统蓝牙权限
        LoggerUtils.d('Android 11-，使用传统蓝牙权限模型');
        //需要蓝牙权限和定位权限
        return [PermissionEnum.bluetooth, PermissionEnum.location];
      }
    }

    return [PermissionEnum.bluetooth, PermissionEnum.location];
  }

  /// 获取相机权限（根据平台和Android版本）
  Future<List<PermissionEnum>> getCameraPermissions() async {
    if (Platform.isIOS) {
      // iOS只需要基础蓝牙权限
      return [PermissionEnum.photos];
    }

    return [PermissionEnum.camera];
  }

  /// 获取相册权限（根据平台和Android版本）
  Future<List<PermissionEnum>> getPhotosPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 32) {
        return [PermissionEnum.storage];
      }
    }
    return [PermissionEnum.photos];
  }

  /// 请求蓝牙权限（智能版本适配）
  Future<bool> requestBluetoothPermissions() async {
    final permissions = await getBluetoothPermissions();
    final results = await requestPermissions(
      permissions,
      customTips: {
        PermissionEnum.bluetoothScan: "bleScanPermissionRequest".tr,
        PermissionEnum.bluetoothConnect: "bleConnectPermissionRequest".tr,
        PermissionEnum.location: "bleLocationPermissionRequest".tr,
      },
    );

    if (Platform.isAndroid) {
      final sdkVersion = await getAndroidSdkVersion();

      if (sdkVersion >= 31) {
        if (await DeviceUtils.instance.isHuaweiPhone()) {
          // Android 12+ 需要扫描和连接权限
          final hasScan = results[PermissionEnum.bluetoothScan] ?? false;
          final hasConnect = results[PermissionEnum.bluetoothConnect] ?? false;
          final hasLocation = results[PermissionEnum.location] ?? false;
          LoggerUtils.d(
            '蓝牙权限结果 华为手机 - 扫描: $hasScan, 连接: $hasConnect, 定位: $hasLocation',
          );
          return hasScan && hasConnect && hasLocation;
        } else {
          // Android 12+ 需要扫描和连接权限
          final hasScan = results[PermissionEnum.bluetoothScan] ?? false;
          final hasConnect = results[PermissionEnum.bluetoothConnect] ?? false;
          final hasLocation = results[PermissionEnum.location] ?? false;
          LoggerUtils.d('蓝牙权限结果 - 扫描: $hasScan, 连接: $hasConnect');
          return hasScan && hasConnect && hasLocation;
        }
      } else {
        // Android 11- 只需要基础蓝牙权限
        final hasBluetooth = results[PermissionEnum.bluetooth] ?? false;
        final hasLocation = results[PermissionEnum.location] ?? false;
        LoggerUtils.d('蓝牙权限结果 - 基础蓝牙: $hasBluetooth 定位: $hasLocation');
        return hasBluetooth && hasLocation;
      }
    }

    // iOS只需要基础蓝牙权限
    final hasBluetooth = results[PermissionEnum.bluetooth] ?? false;
    LoggerUtils.d('蓝牙权限结果 - iOS蓝牙: $hasBluetooth');
    return hasBluetooth;
  }

  /// 请求相机权限（智能版本适配）
  Future<bool> requestCameraPermissions() async {
    final permissions = await getCameraPermissions();
    final results = await requestPermissions(
      permissions,
      customTips: {PermissionEnum.camera: "cameraPermissionRequest".tr},
    );

    // iOS只需要基础蓝牙权限
    final hasCamera = results[permissions.first] ?? false;
    LoggerUtils.d('相机权限结果 - iOS相机: $hasCamera');
    return hasCamera;
  }

  /// 请求相机权限（智能版本适配）
  Future<bool> requestPhotosPermissions(String? customTip) async {
    final permissions = await getPhotosPermissions();
    final results = await requestPermissions(
      permissions,
      customTips: {
        PermissionEnum.photos: customTip ?? "photoPermissionRequest".tr,
      },
    );

    // iOS只需要基础蓝牙权限
    final hasCamera = results[permissions.first] ?? false;
    LoggerUtils.d('相机权限结果 - iOS相机: $hasCamera');
    return hasCamera;
  }

  /// 请求所有蓝牙相关权限
  Future<Map<PermissionEnum, bool>> requestAllBluetoothPermissions() async {
    final permissions = [
      PermissionEnum.bluetooth,
      PermissionEnum.bluetoothScan,
      PermissionEnum.bluetoothConnect,
      PermissionEnum.bluetoothAdvertise,
    ];

    return await requestPermissions(permissions);
  }

  //判断蓝牙是否打开
  Future<bool> isBluetoothEnabled() async {
    return await BluetoothUtils.instance.isBluetoothEnabled();
  }

  /// 检查蓝牙权限状态
  /// 根据平台和版本检查相应的权限
  Future<bool> checkBluetoothPermission() async {
    final permissions = await getBluetoothPermissions();
    final results = await checkPermissions(permissions);
    return results.values.every((granted) => granted);
  }

  /// 显示权限请求前的自定义提示
  Future<bool> showPermissionRequestTip(
    PermissionEnum permission,
    String? customTip,
  ) async {
    final Completer<bool> completer = Completer<bool>();

    // 使用自定义提示或默认提示
    final String message = customTip ?? "needPermissionTip";

    await DialogHelper.showTipDialog(
      message: message,
      title: "permissionRequest",
      okText: "permissionAllow",
      cancelText: "permissionDeny",
      okOntap: () {
        completer.complete(true);
        Get.back();
      },
      cancelOntap: () {
        completer.complete(false);
        Get.back();
      },
    );

    return completer.future;
  }

  /// 显示权限被拒绝的对话框
  Future<void> _showPermissionDeniedDialog(PermissionEnum permission) async {
    var message = "openSettingTip";
    await DialogHelper.showTipDialog(
      message: message,
      title: "requestDenied",
      okText: "Settings",
      cancelText: "cancel",
      okOntap: () async {
        await openAppSettingsPermission();
      },
    );
  }

  /// 显示多个权限被拒绝的对话框
  Future<void> _showMultiplePermissionsDeniedDialog(
    List<PermissionEnum> permissions,
  ) async {
    var message = "requestDeniedTip";
    await DialogHelper.showTipDialog(
      message: message,
      title: "requestDenied",
      okText: "Settings",
      cancelText: "cancel",
      okOntap: () async {
        await openAppSettingsPermission();
      },
    );
  }
}

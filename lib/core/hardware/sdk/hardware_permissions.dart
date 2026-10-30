import 'package:dting/core/hardware/models.dart';
import 'package:flutter/services.dart';

/// 系统运行时权限请求（App 自己的通道，SDK 只做 gate 检查）。
class HardwarePermissions {
  static const MethodChannel _channel = MethodChannel('dting/permissions');

  static Future<void> requestBluetooth() async {
    final granted = await _invoke('requestBluetooth', '蓝牙');
    if (!granted) {
      throw HardwareException(
        HardwareErrorCode.permissionDenied,
        '未授予蓝牙权限，无法扫描/连接录音卡',
      );
    }
  }

  static Future<void> requestWifi() async {
    final granted = await _invoke('requestWifi', '附近设备');
    if (!granted) {
      throw HardwareException(
        HardwareErrorCode.permissionDenied,
        '未授予附近设备/定位权限，无法加入录音卡热点',
      );
    }
  }

  static Future<bool> _invoke(String method, String label) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on MissingPluginException {
      // 非 Android 或未注册通道：不要假装授权成功，交给 SDK 的 gate 报错。
      throw HardwareException(
        HardwareErrorCode.permissionDenied,
        '$label权限通道不可用',
      );
    } on PlatformException catch (error) {
      throw HardwareException(
        HardwareErrorCode.permissionDenied,
        error.message ?? '$label权限请求失败',
      );
    }
  }
}

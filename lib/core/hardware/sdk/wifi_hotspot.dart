import 'package:flutter/services.dart';

/// 设备热点状态（原生侧判断，见 `WifiStateChannel.kt`）。
///
/// 不用 Dart 侧读 SSID：ColorOS 把本应用的位置权限钉成 appop ignore，
/// `WifiInfo.getSSID()` 恒为 `<unknown ssid>`。原生侧改用「当前 WiFi 没有
/// 互联网校验」这个不需要权限的特征——卡的热点正是这种。
class WifiHotspot {
  static const MethodChannel _channel = MethodChannel('dting/wifi_state');

  /// 手机当前是否在卡的热点上。
  static Future<bool> isOnDeviceAccessPoint() async {
    try {
      return await _channel.invokeMethod<bool>('isOnDeviceAccessPoint') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 当前 WiFi 名（可能为 null/`<unknown ssid>`，只用于展示）。
  static Future<String?> currentSsid() async {
    try {
      return await _channel.invokeMethod<String>('currentSsid');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// 打开系统 WLAN 面板，让用户点一下卡的热点。
  static Future<void> openWifiPanel() async {
    try {
      await _channel.invokeMethod<void>('openWifiPanel');
    } on PlatformException {
      // 打不开面板不是致命错误：弹窗里还有热点名可以让用户手填。
    } on MissingPluginException {
      // 同上。
    }
  }
}

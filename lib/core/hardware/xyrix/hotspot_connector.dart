/// 设备热点直连通道（音频外传快传第 2 步：手机连上设备开的热点）。
///
/// Dart 侧统一封装；iOS 由原生 `HotspotChannel.swift`（NEHotspotConfiguration）
/// 实现，Android 未注册 MethodChannel 时返回 unsupported（主战场 iOS 真机）。
library;

import 'package:flutter/services.dart';

/// 手机 ↔ 设备热点的连接器
abstract class HotspotConnector {
  /// 应用热点配置并加入（密码为空表示开放网络）
  Future<void> connect(String ssid, String password);

  /// 移除热点配置（传输结束/失败后调用）
  Future<void> disconnect(String ssid);

  /// 系统当前认为连着的 SSID。用于判断「手机是不是真的进了设备热点」——
  /// 加建议成功只代表系统收下了，不代表连上了，两件事必须分开取证
  Future<({String ssid, bool linked})> currentSsid();
}

class MethodChannelHotspotConnector implements HotspotConnector {
  static const MethodChannel _channel = MethodChannel('dting/hotspot');

  @override
  Future<void> connect(String ssid, String password) async {
    try {
      await _channel.invokeMethod<void>('connect', {
        'ssid': ssid,
        'password': password,
      });
    } on PlatformException catch (e) {
      throw HotspotException(e.code, e.message);
    } on MissingPluginException {
      throw const HotspotException(
          'unsupported', '当前平台未实现热点直连（需 iOS 真机）');
    }
  }

  @override
  Future<void> disconnect(String ssid) async {
    try {
      await _channel.invokeMethod<void>('disconnect', {'ssid': ssid});
    } catch (_) {
      // 移除配置失败不阻塞主流程（传输结果优先）
    }
  }

  @override
  Future<({String ssid, bool linked})> currentSsid() async {
    try {
      final r = await _channel
          .invokeMethod<Map<Object?, Object?>>('currentSsid');
      return (
        ssid: (r?['ssid'] as String?) ?? '',
        linked: (r?['linked'] as bool?) ?? false,
      );
    } catch (_) {
      // 读 SSID 在 Android 上要定位权限；拿不到就如实报「没连上」，不抛
      return (ssid: '', linked: false);
    }
  }
}

class HotspotException implements Exception {
  final String code;
  final String? message;

  const HotspotException(this.code, [this.message]);

  @override
  String toString() => 'HotspotException($code, $message)';
}

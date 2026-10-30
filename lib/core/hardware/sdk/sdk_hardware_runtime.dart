import 'dart:io';

import 'package:dting/config/config.dart';
import 'package:flutter/services.dart';
import 'package:lynse_hardware_contract/lynse_hardware.dart';
import 'package:path_provider/path_provider.dart';

/// 单个 [LynseHardware] 实例的 App 级持有者。
///
/// 先经 App 自己的原生通道把 AppKey / Xyrix 热点参数交给 Native stack，
/// 再初始化 Pigeon；这样凭据不会进入公共 Pigeon 契约。
class SdkHardwareRuntime {
  SdkHardwareRuntime._();

  static final SdkHardwareRuntime instance = SdkHardwareRuntime._();
  static const MethodChannel _configChannel =
      MethodChannel('dting/hardware_sdk_config');

  LynseHardware? _hardware;
  Future<LynseHardware>? _initializing;
  Directory? _downloadDirectory;

  LynseHardware? get hardware => _hardware;

  Directory get downloadDirectory =>
      _downloadDirectory ??
      Directory('${Directory.systemTemp.path}/lynse-hw-downloads');

  Future<LynseHardware> ensureInitialized({required String appKey}) {
    final ready = _hardware;
    if (ready != null) return Future.value(ready);
    return _initializing ??= _initialize(appKey);
  }

  Future<LynseHardware> _initialize(String appKey) async {
    final documents = await getApplicationDocumentsDirectory();
    final downloads = Directory('${documents.path}/LynseDownloads');
    if (!downloads.existsSync()) downloads.createSync(recursive: true);
    _downloadDirectory = downloads;

    final ap = _parseAp(Config.xyrixAp);
    final tcp = _parseTcp(Config.xyrixTcpTarget);
    await _configChannel.invokeMethod<bool>('configure', {
      'newViewAppKey': appKey,
      'newViewRequiresAuthentication': false,
      'newViewWifiVerified': Config.newViewWifiVerified,
      'xyrixWifiVerified': Config.xyrixWifiVerified,
      'xyrixWifiSsid': ap?.ssid ?? '',
      'xyrixWifiPassword': ap?.password ?? '',
      'xyrixWifiHost': tcp?.host ?? '',
      'xyrixWifiPort': tcp?.port ?? 0,
      'downloadDirectory': downloads.path,
    });
    final hardware = await LynseHardware.initialize(
      const LynseConfig(autoReconnect: true),
    );
    _hardware = hardware;
    return hardware;
  }

  static ({String ssid, String password})? _parseAp(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final index = value.indexOf(':');
    if (index < 0) return (ssid: value, password: '');
    return (ssid: value.substring(0, index), password: value.substring(index + 1));
  }

  static ({String host, int port})? _parseTcp(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final index = value.lastIndexOf(':');
    if (index < 0) return (host: value, port: 0);
    return (
      host: value.substring(0, index),
      port: int.tryParse(value.substring(index + 1)) ?? 0,
    );
  }
}

import Flutter
import UIKit
import NetworkExtension

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    NVEasyPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "NVEasyPlugin")!)
    HotspotChannel.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "HotspotChannel")!)
  }
}

/// 设备热点直连通道（Xyrix 音频外传快传第 2 步）。
///
/// 通过 NEHotspotConfigurationManager 让手机加入设备开的热点；
/// 传输结束后由 Dart 侧调用 disconnect 移除配置。
///
/// 注意：使用前需在 Xcode「Signing & Capabilities」为 Runner target
/// 启用 Hotspot Configuration capability（写入描述文件，不产生 entitlements 键），
/// 否则 apply() 返回 Missing Entitlement。
class HotspotChannel: NSObject {

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "dting/hotspot", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "connect":
        guard let args = call.arguments as? [String: Any],
              let ssid = args["ssid"] as? String, !ssid.isEmpty else {
          result(FlutterError(code: "invalid_args", message: "ssid 不能为空", details: nil))
          return
        }
        let password = args["password"] as? String ?? ""
        let config: NEHotspotConfiguration
        if password.isEmpty {
          config = NEHotspotConfiguration(ssid: ssid)
        } else {
          config = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        }
        // 传输会话内保持有效；结束后 Dart 侧显式 removeConfiguration
        config.joinOnce = false
        NEHotspotConfigurationManager.shared.apply(config) { error in
          DispatchQueue.main.async {
            if let error = error as NSError? {
              result(FlutterError(
                code: "apply_failed",
                message: "加入设备热点失败: \(error.localizedDescription)",
                details: ["domain": error.domain, "code": error.code]
              ))
            } else {
              result(nil)
            }
          }
        }
      case "disconnect":
        if let args = call.arguments as? [String: Any],
           let ssid = args["ssid"] as? String, !ssid.isEmpty {
          NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

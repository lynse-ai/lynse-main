import Foundation
import Flutter
import NVEasySDK

/// OTA升级相关方法处理器
class OTAMethodHandler: BaseMethodHandler {
    
    override func handle(method: String, arguments: [String: Any]?, result: @escaping FlutterResult) -> Bool {
        switch method {
        case "deviceOta":
            if let arguments = arguments,
               let otaFilePath = arguments["otaFilePath"] as? String,
               let newVersion = arguments["newVersion"] as? String {
                
                // 检查文件是否存在
                let fileURL = URL(fileURLWithPath: otaFilePath)
                guard FileManager.default.fileExists(atPath: otaFilePath) else {
                    BLELogger.error("❌ [OTA升级] 文件不存在: \(otaFilePath)")
                    
                    // 发送升级失败状态到Flutter端
                    let arguments: [String: Any] = [
                        "status": 3, // FAILED
                        "progress": 0,
                        "upgradedSize": 0,
                        "error": "OTA file not found"
                    ]
                    NVEasyPlugin.methodChannel?.invokeMethod("deviceUpdateOtaStatus", arguments: arguments)
                    
                    result(FlutterError(code: "FILE_NOT_FOUND", 
                                      message: "OTA file not found: \(otaFilePath)", 
                                      details: nil))
                    return true
                }
                
                BLELogger.log("🔄 [OTA升级] 开始升级，文件路径: \(otaFilePath), 版本: \(newVersion)")
                
                // 执行OTA升级
                NVEasyBLEManager.shared.otaManager.upgrade(to: newVersion, with: fileURL)
                
                result("deviceOta!")
                return true
            } else {
                result(FlutterError(code: NVEasyConstants.ErrorCodes.invalidArguments, 
                                  message: "OTA file path and new version are required", 
                                  details: nil))
                return true
            }
            
        default:
            return false
        }
    }
}

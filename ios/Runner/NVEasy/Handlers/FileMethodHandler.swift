import Foundation
import Flutter

/// 文件相关方法处理器
class FileMethodHandler: BaseMethodHandler {
    
    private let fileManager: NVFileManager
    
    init(fileManager: NVFileManager) {
        self.fileManager = fileManager
    }
    
    override func handle(method: String, arguments: [String: Any]?, result: @escaping FlutterResult) -> Bool {
        switch method {
        // File Methods
        case "getFileList":
            fileManager.getFileList()
            result("getFileList!")
            return true
            
        case "downloadFile":
            if let arguments = arguments,
               let fileSN = arguments["sn"] as? Int {
                fileManager.downloadFile(sn: fileSN)
                result("downloadFile!")
                return true
            } else {
                result(FlutterError(code: NVEasyConstants.ErrorCodes.invalidArguments, 
                                  message: "File SN is required", 
                                  details: nil))
                return true
            }
            
        case "downloadFileWithOffset":
            if let arguments = arguments,
               let fileSN = arguments["sn"] as? Int,
               let offsetInBytes = arguments["offsetInBytes"] as? Int {
                fileManager.downloadFile(sn: fileSN, offsetInBytes: offsetInBytes)
                result("downloadFileWithOffset!")
                return true
            } else {
                result(FlutterError(code: NVEasyConstants.ErrorCodes.invalidArguments, 
                                  message: "File SN and offsetInBytes are required", 
                                  details: nil))
                return true
            }
            
        case "downloadFileOfWifi":
            if let arguments = arguments,
               let fileSN = arguments["sn"] as? Int {
//                fileManager.downloadFileByWifi(sn: fileSN)
                result("downloadFileOfWifi!")
                return true
            } else {
                result(FlutterError(code: NVEasyConstants.ErrorCodes.invalidArguments, 
                                  message: "File SN is required", 
                                  details: nil))
                return true
            }
            
        case "closeWiFi":
            fileManager.closeWiFi()
            result("closeWiFi!")
            return true
            
        default:
            return false
        }
    }
}

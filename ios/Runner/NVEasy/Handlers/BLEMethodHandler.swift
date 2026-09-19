import Foundation
import Flutter

/// BLE相关方法处理器
class BLEMethodHandler: BaseMethodHandler {
    
    private let bleManager: BLEManager
    
    init(bleManager: BLEManager) {
        self.bleManager = bleManager
    }
    
    override func handle(method: String, arguments: [String: Any]?, result: @escaping FlutterResult) -> Bool {
        switch method {
        // BLE Methods
        case "startScan":
            bleManager.startScan()
            result("startScan!")
            return true
            
        case "stopScan":
            bleManager.stopScan()
            result("stopScan!")
            return true
            
        case "startConnect":
            if let arguments = arguments,
               let uuid = arguments["uuid"] as? String {
                bleManager.connect(uuid)
                result("startConnect!")
                return true
            } else {
                            ErrorManager.shared.handleParameterError(missingParameter: "uuid", result: result)
                return true
            }
            
        case "startDisconnect":
            if let arguments = arguments,
               let uuid = arguments["uuid"] as? String {
                bleManager.disconnect(uuid)
                result("startDisconnect!")
                return true
            } else {
                result(FlutterError(code: NVEasyConstants.ErrorCodes.invalidArguments, 
                                  message: "UUID is required", 
                                  details: nil))
                return true
            }
            
        // Device Control Methods
        case "resetDevice":
            bleManager.resetDevice()
            result("resetDevice!")
            return true
            
        case "queryVersion":
            bleManager.queryVersion()
            result("queryVersion!")
            return true
            
        case "querySN":
            bleManager.querySN()
            result("querySN!")
            return true
            
        case "setName":
            if let arguments = arguments,
               let name = arguments["name"] as? String {
                bleManager.setName(name)
                result("setName!")
                return true
            } else {
                result(FlutterError(code: NVEasyConstants.ErrorCodes.invalidArguments, 
                                  message: "Name is required", 
                                  details: nil))
                return true
            }
            
        case "getBattery":
            bleManager.getBattery()
            result("getBattery!")
            return true
            
        case "offtime":
            if let arguments = arguments,
               let minutes = arguments["minutes"] as? Int {
                bleManager.setOffTime(minutes: minutes)
                result("offtime!")
                return true
            } else {
                result(FlutterError(code: NVEasyConstants.ErrorCodes.invalidArguments, 
                                  message: "Minutes is required", 
                                  details: nil))
                return true
            }
            
        case "getBindStatus":
            let bindStatus = bleManager.getBindStatus()
            result(bindStatus)
            return true
            
        case "bindDevice":
            if let arguments = arguments,
               let isBind = arguments["isBind"] as? Bool {
                bleManager.bindDevice(isBind: isBind)
                result("bindDevice!")
                return true
            } else {
                result(FlutterError(code: NVEasyConstants.ErrorCodes.invalidArguments, 
                                  message: "isBind parameter is required", 
                                  details: nil))
                return true
            }
            
        case "autoConnect":
            if let arguments = arguments,
               let uuid = arguments["uuid"] as? String {
                // 自动连接逻辑
                result("autoConnect!")
                return true
            } else {
                result(FlutterError(code: NVEasyConstants.ErrorCodes.invalidArguments, 
                                  message: "UUID is required", 
                                  details: nil))
                return true
            }
            
        default:
            return false
        }
    }
}

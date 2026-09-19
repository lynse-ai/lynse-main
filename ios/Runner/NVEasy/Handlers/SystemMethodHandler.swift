import Foundation
import Flutter
import UIKit

/// 系统相关方法处理器
class SystemMethodHandler: BaseMethodHandler {
    
    override func handle(method: String, arguments: [String: Any]?, result: @escaping FlutterResult) -> Bool {
        switch method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            return true
            
        case "clearCommandQueue":
            CommandQueueManager.shared.clearExecutionTimes()
            result("clearCommandQueue!")
            return true
            
        default:
            return false
        }
    }
}

import Foundation
import Flutter

/// 音频相关方法处理器
class AudioMethodHandler: BaseMethodHandler {
    
    private let audioManager: BLERecordManager
    
    init(audioManager: BLERecordManager) {
        self.audioManager = audioManager
    }
    
    override func handle(method: String, arguments: [String: Any]?, result: @escaping FlutterResult) -> Bool {
        switch method {
        case "initOpus":
            let mono = arguments?["mono"] as? Bool ?? false
            audioManager.initOpus(mono: mono)
            result("initOpus!")
            return true
            
        // Recording Methods
        case "startRecord":
            audioManager.startRecord()
            result("startRecord!")
            return true
            
        case "pauseRecord":
            audioManager.pauseRecord()
            result("pauseRecord!")
            return true
            
        case "resumeRecord":
            audioManager.resumeRecord()
            result("resumeRecord!")
            return true
            
        case "stopRecord":
            let fileInfo = audioManager.stopRecord()
            result(fileInfo)
            return true
            
        default:
            return false
        }
    }
}

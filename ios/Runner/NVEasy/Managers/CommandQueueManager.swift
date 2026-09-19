import Foundation

/// 简化的指令队列管理器
class CommandQueueManager: CommandQueueManagerProtocol {
    static let shared = CommandQueueManager()
    
    // MARK: - Properties
    
    /// 指令去重映射表 (指令类型 -> 最后执行时间)
    private var lastExecutionTimes: [String: Date] = [:]
    
    /// 指令防抖间隔 (秒)
    private let debounceIntervals: [String: TimeInterval] = [
        "startScan": 2.0,
        "stopScan": 1.0,
        "startConnect": 3.0,
        "startDisconnect": 1.0,
        "bindDevice": 2.0,
        "getBattery": 5.0,
        "queryVersion": 10.0,
        "querySN": 10.0,
        "setName": 2.0,
        "setOffTime": 2.0,
        "resetDevice": 5.0,
        "getFileList": 3.0,
        "downloadFile": 1.0,
        "downloadFileWithOffset": 1.0,
        "downloadFileOfWifi": 1.0,
        "closeWiFi": 2.0,
        "deviceOta": 30.0,
        "resumeTransfer": 2.0,
        "clearTransferState": 1.0,
        "clearAllTransferStates": 1.0,
        "clearCompletedTransfers": 1.0,
        "getResumableTransfers": 5.0,
        "startRecord": 2.0,
        "pauseRecord": 1.0,
        "resumeRecord": 1.0,
        "stopRecord": 2.0,
        "initOpus": 5.0,
        "autoConnect": 3.0,
        "getBindStatus": 5.0,
        "getPlatformVersion": 60.0
    ]
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 检查是否应该防抖
    func shouldDebounceCommand(type: String) -> Bool {
        guard let interval = debounceIntervals[type],
              let lastTime = lastExecutionTimes[type] else {
            return false
        }
        
        let timeSinceLastExecution = Date().timeIntervalSince(lastTime)
        return timeSinceLastExecution < interval
    }
    
    /// 更新最后执行时间
    func updateLastExecutionTime(type: String) {
        lastExecutionTimes[type] = Date()
    }
    
    /// 清空执行时间记录
    func clearExecutionTimes() {
        lastExecutionTimes.removeAll()
    }
}

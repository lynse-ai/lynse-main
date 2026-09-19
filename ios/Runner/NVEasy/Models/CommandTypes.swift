import Foundation

// MARK: - Command Types

/// 指令类型枚举
enum CommandType: String, CaseIterable {
    case startScan = "startScan"
    case stopScan = "stopScan"
    case startConnect = "startConnect"
    case startDisconnect = "startDisconnect"
    case bindDevice = "bindDevice"
    case getBattery = "getBattery"
    case queryVersion = "queryVersion"
    case querySN = "querySN"
    case setName = "setName"
    case setOffTime = "setOffTime"
    case resetDevice = "resetDevice"
    case getFileList = "getFileList"
    case downloadFile = "downloadFile"
    case downloadFileWithOffset = "downloadFileWithOffset"
    case downloadFileOfWifi = "downloadFileOfWifi"
    case closeWiFi = "closeWiFi"
    case deviceOta = "deviceOta"
    case resumeTransfer = "resumeTransfer"
    case clearTransferState = "clearTransferState"
    case clearAllTransferStates = "clearAllTransferStates"
    case clearCompletedTransfers = "clearCompletedTransfers"
    case getResumableTransfers = "getResumableTransfers"
    case startRecord = "startRecord"
    case pauseRecord = "pauseRecord"
    case resumeRecord = "resumeRecord"
    case stopRecord = "stopRecord"
    case initOpus = "initOpus"
    case autoConnect = "autoConnect"
    case getBindStatus = "getBindStatus"
    case getPlatformVersion = "getPlatformVersion"
}

/// 指令优先级
enum CommandPriority: Int, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

/// 指令状态
enum CommandStatus {
    case pending
    case executing
    case completed
    case failed
    case cancelled
}

/// 指令项
struct CommandItem {
    let id: String
    let type: CommandType
    let priority: CommandPriority
    let arguments: [String: Any]?
    let timestamp: Date
    var status: CommandStatus
    var retryCount: Int
    let maxRetries: Int
    let timeout: TimeInterval
    
    init(type: CommandType, 
         priority: CommandPriority = .normal,
         arguments: [String: Any]? = nil,
         maxRetries: Int = 3,
         timeout: TimeInterval = 10.0) {
        self.id = UUID().uuidString
        self.type = type
        self.priority = priority
        self.arguments = arguments
        self.timestamp = Date()
        self.status = .pending
        self.retryCount = 0
        self.maxRetries = maxRetries
        self.timeout = timeout
    }
}

import Foundation

/// 定义事件类型枚举
enum NVEasyEventType: String, CaseIterable {
    case recordMP3File = "recordMP3File"           // 录音MP3文件路径
    case deviceState = "deviceState"               // 设备状态变化
    case batteryUpdate = "batteryUpdate"           // 电池状态更新
    case deviceFiles = "deviceFiles"               // 设备文件列表
    case transcribeStatus = "transcribeStatus"     // 转写状态
    case didUpdateMeetingType = "didUpdateMeetingType" // 设备模式变换
    case error = "error"                           // 错误信息
    case otaStatus = "deviceUpdateOtaStatus"       // OTA升级状态
}

/// 事件数据结构
struct EventData {
    let type: NVEasyEventType
    let data: Any?
    let timestamp: Date
    
    init(type: NVEasyEventType, data: Any? = nil) {
        self.type = type
        self.data = data
        self.timestamp = Date()
    }
    
    /// 转换为Flutter事件格式
    func toFlutterEvent() -> [String: Any] {
        return [
            "type": type.rawValue,
            "data": data ?? NSNull(),
            "timestamp": timestamp.timeIntervalSince1970
        ]
    }
}

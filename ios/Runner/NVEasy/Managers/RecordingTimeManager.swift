import Foundation

/// 录音时间管理器
/// 负责管理录音的开始时间、持续时间和相关的时间格式化
class RecordingTimeManager: RecordingTimeManagerProtocol {
    
    // MARK: - Singleton
    static let shared = RecordingTimeManager()
    
    // MARK: - Properties
    
    /// 上次开始录音的时间
    private var lastStartRecordTime: Date?
    
    /// 访问锁
    private let timeLock = NSLock()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 设置录音开始时间
    func setRecordStartTime() {
        lastStartRecordTime = Date()
        NVEasyLogger.info("🎤 [录音时间] 设置录音开始时间: \(formatRecordStartTimeToString())")
    }
    
    /// 获取录音开始时间
    /// - Returns: 录音开始时间，如果未开始录音则返回nil
    func getRecordStartTime() -> Date? {
        return lastStartRecordTime
    }
    
    /// 清除录音开始时间
    func clearRecordStartTime() {
        lastStartRecordTime = nil
        NVEasyLogger.info("🎤 [录音时间] 清除录音开始时间")
    }
    
    /// 获取录音持续时间
    /// - Returns: 录音持续时间（秒），如果未开始录音则返回0
    func getRecordDuration() -> TimeInterval {
        guard let startTime = lastStartRecordTime else {
            return 0
        }
        return Date().timeIntervalSince(startTime)
    }
    
    /// 检查是否正在录音
    /// - Returns: 是否正在录音
    func isRecording() -> Bool {
        return lastStartRecordTime != nil
    }
    
    // MARK: - Date Formatting Methods
    
    /// 格式化日期为字符串
    /// - Parameter date: 要格式化的日期
    /// - Returns: 格式化后的日期字符串 (yyyy-MM-dd HH:mm:ss)
    func formatDateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    /// 格式化当前日期为字符串
    /// - Returns: 当前日期的格式化字符串 (yyyy-MM-dd HH:mm:ss)
    func formatCurrentDateToString() -> String {
        return formatDateToString(Date())
    }
    
    /// 格式化录音开始时间为字符串
    /// - Returns: 录音开始时间的格式化字符串，如果未开始录音则返回"未开始"
    func formatRecordStartTimeToString() -> String {
        guard let startTime = lastStartRecordTime else {
            return "未开始"
        }
        return formatDateToString(startTime)
    }
    
    /// 格式化录音持续时间为字符串
    /// - Returns: 录音持续时间的格式化字符串 (HH:mm:ss)
    func formatRecordDurationToString() -> String {
        let duration = getRecordDuration()
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// 获取录音状态信息
    /// - Returns: 录音状态信息字典
    func getRecordingStatusInfo() -> [String: Any] {
        return [
            "isRecording": lastStartRecordTime != nil,
            "startTime": lastStartRecordTime?.timeIntervalSince1970 ?? 0,
            "duration": getRecordDuration(),
            "formattedStartTime": formatRecordStartTimeToString(),
            "formattedDuration": formatRecordDurationToString()
        ]
    }
    
    /// 重置所有录音时间状态
    func resetRecordingTime() {
        lastStartRecordTime = nil
        NVEasyLogger.info("🎤 [录音时间] 重置所有录音时间状态")
    }
}

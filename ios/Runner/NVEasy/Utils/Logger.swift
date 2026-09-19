import Foundation
import os.log

/// 统一的日志管理器
/// 整合了NVEasyLogger和BLELogger的功能
class NVEasyLogger {
    
    // MARK: - Log Levels
    
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        case success = "SUCCESS"
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            case .success: return "✅"
            }
        }
    }
    
    // MARK: - Properties
    
    /// 是否启用日志打印
    static var isEnabled: Bool = true
    
    private static let subsystem = NVEasyConstants.Logging.subsystem
    private static let category = NVEasyConstants.Logging.category
    private static let osLogger = OSLog(subsystem: subsystem, category: category)
    
    // MARK: - Public Methods
    
    /// 记录调试信息
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    /// 记录一般信息
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    /// 记录警告信息
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    /// 记录错误信息
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, file: file, function: function, line: line)
    }
    
    /// 记录严重错误信息
    static func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .critical, message: message, file: file, function: function, line: line)
    }
    
    /// 记录成功信息
    static func success(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .success, message: message, file: file, function: function, line: line)
    }
    
    /// 简化的日志方法（兼容BLELogger）
    static func log(_ message: String) {
        if isEnabled {
            info(message)
        }
    }
    
    // MARK: - Private Methods
    
    private static func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        guard isEnabled else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = DateFormatter.timestamp.string(from: Date())
        let logMessage = "[\(timestamp)] \(level.emoji) [\(level.rawValue)] [\(fileName):\(line)] \(function): \(message)"
        
        // 只使用控制台输出，避免重复
        print(logMessage)
        
        // 注释掉系统日志输出，避免重复
        // let osLogType: OSLogType = {
        //     switch level {
        //     case .debug: return .debug
        //     case .info: return .info
        //     case .warning: return .default
        //     case .error: return .error
        //     case .critical: return .fault
        //     case .success: return .info
        //     }
        // }()
        // 
        // os_log("%{public}@", log: osLogger, type: osLogType, logMessage)
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

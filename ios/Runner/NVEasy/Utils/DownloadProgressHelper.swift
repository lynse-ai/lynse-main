import Foundation
import Flutter

/// 下载进度辅助类
/// 负责处理文件下载进度的计算和通知
class DownloadProgressHelper {
    
    // MARK: - Public Methods
    
    /// 发送文件下载进度到Flutter端
    /// - Parameters:
    ///   - currentPacket: 当前包数
    ///   - totalPacket: 总包数
    ///   - currentNumber: 当前文件编号
    static func sendDownloadFileProgress(currentPacket: Int, totalPacket: Int, currentNumber: Int) {
        let progress = [
            "currentPacket": currentPacket,
            "totalPacket": totalPacket,
            "currentNumber": currentNumber
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("didUpdateDownloadFileProgress", arguments: progress)
        BLELogger.log("📊 [下载进度] 文件 \(currentNumber): \(currentPacket)/\(totalPacket)")
    }
    
    /// 发送文件下载速度到Flutter端
    /// - Parameter speedKbps: 下载速度（KB/s）
    static func sendFileDownloadSpeed(speedKbps: Int) {
        let speed = ["speedKbps": speedKbps]
        NVEasyPlugin.methodChannel?.invokeMethod("fileDownloadSpeed", arguments: speed)
        BLELogger.log("🚀 [下载速度] \(speedKbps) KB/s")
    }
    
    /// 计算下载进度百分比
    /// - Parameters:
    ///   - currentPacket: 当前包数
    ///   - totalPacket: 总包数
    /// - Returns: 进度百分比 (0-100)
    static func calculateProgress(currentPacket: Int, totalPacket: Int) -> Double {
        guard totalPacket > 0 else { return 0.0 }
        return Double(currentPacket) / Double(totalPacket) * 100.0
    }
    
    /// 格式化进度字符串
    /// - Parameters:
    ///   - currentPacket: 当前包数
    ///   - totalPacket: 总包数
    /// - Returns: 格式化的进度字符串
    static func formatProgressString(currentPacket: Int, totalPacket: Int) -> String {
        let progress = calculateProgress(currentPacket: currentPacket, totalPacket: totalPacket)
        return String(format: "%.1f%%", progress)
    }
}

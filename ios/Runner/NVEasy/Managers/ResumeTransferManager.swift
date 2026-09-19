import Foundation
import NVEasySDK

/// 断点续传管理器
class ResumeTransferManager: NSObject, ResumeTransferManagerProtocol {
    
    // MARK: - Singleton
    static let shared = ResumeTransferManager()
    private override init() {
        super.init()
        loadTransferStates()
    }
    
    // MARK: - Properties
    
    /// 传输状态存储路径
    private let transferStatesPath: String = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(NVEasyConstants.FilePaths.transferStatesFileName).path
    }()
    
    /// 当前传输状态
    private var currentTransferStates: [Int: TransferState] = [:]
    
    /// 传输状态锁
    private let transferLock = NSLock()
    
    // MARK: - Transfer State Model
    
    /// 传输状态模型
    struct TransferState: Codable {
        let fileSN: Int
        let fileName: String
        let fileSize: Int
        var totalPackets: Int
        var receivedPackets: Int
        var receivedBytes: Int
        var lastPacketTime: Date
        var isCompleted: Bool
        var errorMessage: String?
        
        /// 计算传输进度
        var progress: Double {
            guard totalPackets > 0 else { return 0.0 }
            return Double(receivedPackets) / Double(totalPackets)
        }
        
        /// 计算传输速度 (bytes/second)
        var transferSpeed: Double {
            let timeInterval = Date().timeIntervalSince(lastPacketTime)
            guard timeInterval > 0 else { return 0.0 }
            return Double(receivedBytes) / timeInterval
        }
        
        /// 检查是否可以恢复传输
        var canResume: Bool {
            return !isCompleted && receivedPackets > 0 && receivedPackets < totalPackets
        }
        
        /// 获取下一个包号
        var nextPacketNumber: Int {
            return receivedPackets + 1
        }
        
        /// 获取剩余字节数
        var remainingBytes: Int {
            return fileSize - receivedBytes
        }
    }
    
    // MARK: - Public Methods
    
    /// 开始文件传输
    /// - Parameter file: 文件信息
    func startTransfer(file: NVEasyFileInfo) {
        let transferState = TransferState(
            fileSN: file.sn,
            fileName: file.name,
            fileSize: file.size,
            totalPackets: 0, // 初始化为0，等待实际总包数
            receivedPackets: 0,
            receivedBytes: 0,
            lastPacketTime: Date(),
            isCompleted: false,
            errorMessage: nil
        )
        
        currentTransferStates[file.sn] = transferState
        saveTransferStates()
        
        BLELogger.log("🔄 [断点续传] 开始传输文件: \(file.name), SN: \(file.sn)")
    }
    
    /// 更新传输进度
    /// - Parameters:
    ///   - fileSN: 文件序列号
    ///   - packetNumber: 包号
    ///   - dataSize: 数据大小
    func updateTransferProgress(fileSN: Int, receivedPackets: Int, totalPackets: Int, receivedBytes: Int) {
        guard var state = currentTransferStates[fileSN] else {
            BLELogger.error("❌ [断点续传] 未找到文件 \(fileSN) 的传输状态")
            return
        }
        
        // 更新传输状态
        state.receivedPackets = receivedPackets
        state.receivedBytes = receivedBytes
        state.lastPacketTime = Date()
        
        currentTransferStates[fileSN] = state
        saveTransferStates()
        
        BLELogger.log("📊 [断点续传] 文件 \(fileSN) 进度: \(String(format: "%.1f", state.progress * 100))% (\(receivedPackets)/\(totalPackets))")
    }
    
    /// 完成文件传输
    /// - Parameter fileSN: 文件序列号
    func completeTransfer(fileSN: Int, success: Bool, error: Error?) {
        guard var state = currentTransferStates[fileSN] else {
            BLELogger.error("❌ [断点续传] 未找到文件 \(fileSN) 的传输状态")
            return
        }
        
        state.isCompleted = true
        state.receivedPackets = state.totalPackets
        state.receivedBytes = state.fileSize
        
        currentTransferStates[fileSN] = state
        saveTransferStates()
        
        BLELogger.success("✅ [断点续传] 文件 \(fileSN) 传输完成")
    }
    
    /// 检查是否有传输状态
    /// - Parameter fileSN: 文件序列号
    /// - Returns: 是否有传输状态
    func hasTransferState(fileSN: Int) -> Bool {
        return currentTransferStates[fileSN] != nil
    }
    
    /// 检查传输是否完成
    /// - Parameter fileSN: 文件序列号
    /// - Returns: 是否完成
    func isTransferCompleted(fileSN: Int) -> Bool {
        guard let state = currentTransferStates[fileSN] else {
            return false
        }
        
        return state.isCompleted
    }
    
    /// 传输失败
    /// - Parameters:
    ///   - fileSN: 文件序列号
    ///   - error: 错误信息
    func transferFailed(fileSN: Int, error: String) {
        guard var state = currentTransferStates[fileSN] else {
            BLELogger.error("❌ [断点续传] 未找到文件 \(fileSN) 的传输状态")
            return
        }
        
        state.errorMessage = error
        currentTransferStates[fileSN] = state
        saveTransferStates()
        
        BLELogger.error("❌ [断点续传] 文件 \(fileSN) 传输失败: \(error)")
    }
    
    /// 检查是否可以恢复传输
    /// - Parameter fileSN: 文件序列号
    /// - Returns: 是否可以恢复
    func canResumeTransfer(fileSN: Int) -> Bool {
        guard let state = currentTransferStates[fileSN] else {
            return false
        }
        
        return state.canResume
    }
    
    /// 获取传输状态
    /// - Parameter fileSN: 文件序列号
    /// - Returns: 传输状态
    func getTransferState(fileSN: Int) -> Any? {
        return currentTransferStates[fileSN]
    }
    
    /// 获取所有可恢复的传输
    /// - Returns: 可恢复的传输列表
    func getResumableTransfers() -> [Any] {
        return currentTransferStates.values.filter { $0.canResume }
    }
    
    /// 恢复文件传输
    /// - Parameter fileSN: 文件序列号
    /// - Returns: 是否成功恢复
    func resumeTransfer(fileSN: Int) -> Bool {
        guard let state = currentTransferStates[fileSN],
              state.canResume else {
            BLELogger.error("❌ [断点续传] 文件 \(fileSN) 无法恢复传输")
            return false
        }
        
        // 计算偏移量（字节）
        let offsetInBytes = state.receivedBytes
        
        BLELogger.log("🔄 [断点续传] 恢复文件 \(fileSN) 传输，从字节 \(offsetInBytes) 开始")
        
        // 调用SDK的断点续传功能
        NVEasyFileManager.shared.getFile(sn: fileSN, autoDelete: true, offsetInBytes: offsetInBytes)
        
        return true
    }
    
    /// 清理传输状态
    /// - Parameter fileSN: 文件序列号
    func clearTransferState(fileSN: Int) {
        currentTransferStates.removeValue(forKey: fileSN)
        saveTransferStates()
        
        BLELogger.log("🗑️ [断点续传] 清理文件 \(fileSN) 的传输状态")
    }
    
    /// 清理所有传输状态
    func clearAllTransferStates() {
        currentTransferStates.removeAll()
        saveTransferStates()
        
        BLELogger.log("🗑️ [断点续传] 清理所有传输状态")
    }
    
    /// 清理已完成的传输状态
    func clearCompletedTransfers() {
        let completedFileSNs = currentTransferStates.keys.filter { fileSN in
            currentTransferStates[fileSN]?.isCompleted == true
        }
        
        for fileSN in completedFileSNs {
            currentTransferStates.removeValue(forKey: fileSN)
        }
        
        if !completedFileSNs.isEmpty {
            saveTransferStates()
            BLELogger.log("🗑️ [断点续传] 清理 \(completedFileSNs.count) 个已完成的传输状态")
        }
    }
    
    /// 更新总包数
    /// - Parameters:
    ///   - fileSN: 文件序列号
    ///   - totalPackets: 实际总包数
    func updateTotalPackets(fileSN: Int, totalPackets: Int) {
        guard var state = currentTransferStates[fileSN] else {
            BLELogger.error("❌ [断点续传] 未找到文件 \(fileSN) 的传输状态")
            return
        }
        
        state.totalPackets = totalPackets
        currentTransferStates[fileSN] = state
        saveTransferStates()
        
        BLELogger.log("📊 [断点续传] 文件 \(fileSN) 更新总包数: \(totalPackets)")
    }
    
    // MARK: - Private Methods
    
    /// 计算总包数
    /// - Parameter fileSize: 文件大小
    /// - Returns: 总包数
    private func calculateTotalPackets(fileSize: Int) -> Int {
        // 假设每个包的大小为512字节（可根据实际情况调整）
        let packetSize = 512
        return (fileSize + packetSize - 1) / packetSize
    }
    
    /// 保存传输状态到文件
    private func saveTransferStates() {
        do {
            let data = try JSONEncoder().encode(currentTransferStates)
            try data.write(to: URL(fileURLWithPath: transferStatesPath))
            BLELogger.log("💾 [断点续传] 传输状态已保存")
        } catch {
            BLELogger.error("❌ [断点续传] 保存传输状态失败: \(error)")
        }
    }
    
    /// 从文件加载传输状态
    private func loadTransferStates() {
        guard FileManager.default.fileExists(atPath: transferStatesPath) else {
            BLELogger.log("📁 [断点续传] 传输状态文件不存在，使用空状态")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: transferStatesPath))
            let states = try JSONDecoder().decode([Int: TransferState].self, from: data)
            currentTransferStates = states
            
            let resumableCount = states.values.filter { $0.canResume }.count
            BLELogger.log("📁 [断点续传] 加载传输状态完成，可恢复传输: \(resumableCount) 个")
        } catch {
            BLELogger.error("❌ [断点续传] 加载传输状态失败: \(error)")
            currentTransferStates = [:]
        }
    }
}

// MARK: - Transfer State Extensions

extension ResumeTransferManager.TransferState {
    /// 格式化进度字符串
    var progressString: String {
        return String(format: "%.1f%%", progress * 100)
    }
    
    /// 格式化速度字符串
    var speedString: String {
        let speedKBps = transferSpeed / 1024.0
        return String(format: "%.1f KB/s", speedKBps)
    }
    
    /// 格式化剩余时间字符串
    var remainingTimeString: String {
        guard transferSpeed > 0 else { return "未知" }
        let remainingSeconds = Double(remainingBytes) / transferSpeed
        return formatTime(seconds: remainingSeconds)
    }
    
    /// 格式化时间
    private func formatTime(seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}


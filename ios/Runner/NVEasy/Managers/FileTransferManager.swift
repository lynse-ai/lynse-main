import Foundation
import NVEasySDK

/// 文件传输管理器
/// 负责管理文件传输状态和进度
class FileTransferManager: FileTransferManagerProtocol {
    
    // MARK: - Singleton
    
    static let shared = FileTransferManager()
    
    // MARK: - Properties
    
    // 防止重复处理同一个文件的完成回调
    private static var processedFiles = Set<Int>()
    private static var processedWifiFiles = Set<Int>()
    
    // 防止重复处理同一个文件的传输
    private static var currentTransferFileSN: Int? = nil
    private static var currentWifiTransferFileSN: Int? = nil
    
    // OPUS 传输开始时间
    private static var opusStartTime: Date? = nil
    
    // 串行下载相关属性
    var pendingFiles: [NVEasyFileInfo] = []
    var currentDownloadIndex: Int = 0
    var isDownloading: Bool = false
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - File Transfer State Management
    
    /// 检查文件是否已处理过
    static func isFileProcessed(fileSN: Int) -> Bool {
        return processedFiles.contains(fileSN)
    }
    
    /// 标记文件为已处理
    static func markFileAsProcessed(fileSN: Int) {
        processedFiles.insert(fileSN)
    }
    
    /// 检查WiFi文件是否已处理过
    static func isWifiFileProcessed(fileSN: Int) -> Bool {
        return processedWifiFiles.contains(fileSN)
    }
    
    /// 标记WiFi文件为已处理
    static func markWifiFileAsProcessed(fileSN: Int) {
        processedWifiFiles.insert(fileSN)
    }
    
    /// 设置当前传输的文件SN
    static func setCurrentTransferFileSN(_ fileSN: Int?) {
        currentTransferFileSN = fileSN
    }
    
    /// 获取当前传输的文件SN
    static func getCurrentTransferFileSN() -> Int? {
        return currentTransferFileSN
    }
    
    /// 设置当前WiFi传输的文件SN
    static func setCurrentWifiTransferFileSN(_ fileSN: Int?) {
        currentWifiTransferFileSN = fileSN
    }
    
    /// 获取当前WiFi传输的文件SN
    static func getCurrentWifiTransferFileSN() -> Int? {
        return currentWifiTransferFileSN
    }
    
    // MARK: - OPUS Transfer Time Management
    
    /// 设置 OPUS 传输开始时间
    static func setOpusStartTime(_ time: Date?) {
        opusStartTime = time
    }
    
    /// 获取 OPUS 传输开始时间
    static func getOpusStartTime() -> Date? {
        return opusStartTime
    }
    
    /// 清理 OPUS 传输开始时间
    static func clearOpusStartTime() {
        opusStartTime = nil
    }
    
    /// 清理所有文件传输状态
    static func clearAllFileTransferStates() {
        processedFiles.removeAll()
        processedWifiFiles.removeAll()
        currentTransferFileSN = nil
        currentWifiTransferFileSN = nil
        opusStartTime = nil
    }
    
    // MARK: - Serial Download Management
    
    /// 清理串行下载状态
    func clearSerialDownloadState() {
        currentDownloadIndex = 0
        isDownloading = false
        // 清理所有文件的音频数据
        AudioDataManager.shared.clearAllFileAudioData()
    }
    
    /// 检查是否正在下载
    func isCurrentlyDownloading() -> Bool {
        return isDownloading
    }
    
    /// 停止串行下载
    func stopSerialDownload() {
        BLELogger.log("🛑 [文件传输管理] 停止串行下载")
        isDownloading = false
        currentDownloadIndex = 0
    }
    
    /// 获取下载进度
    func getDownloadProgress() -> (current: Int, total: Int, isDownloading: Bool) {
        return (current: currentDownloadIndex, total: pendingFiles.count, isDownloading: isDownloading)
    }
    
    // MARK: - Download Operations
    
    /// 开始下载所有文件，通过蓝牙（串行下载）
    /// - Parameter files: 要下载的文件列表
    func startDownloadAllFilesViaBluetooth(files: [NVEasyFileInfo]) {
        BLELogger.log("📁 [文件传输管理] 开始串行批量下载 \(files.count) 个文件")
        
        // 检查蓝牙连接状态
        guard NVEasyBLEManager.shared.isConnected else {
            BLELogger.error("❌ [文件传输管理] 蓝牙未连接，无法下载文件")
            return
        }
        
        // 检查是否已经在下载中
        guard !self.isDownloading else {
            BLELogger.warning("⚠️ [文件传输管理] 已有下载任务正在进行中，跳过此次请求")
            return
        }
        
        // 预处理文件列表，检查断点续传状态
        let processedFiles = preprocessFilesForDownload(files: files)
        
        // 存储待下载的文件列表和当前下载状态
        self.pendingFiles = processedFiles
        self.currentDownloadIndex = 0
        self.isDownloading = true
        
        BLELogger.log("📁 [文件传输管理] 预处理完成，准备下载 \(processedFiles.count) 个文件")
        
        // 开始下载第一个文件
        startNextFileDownload()
    }
    
    /// 预处理文件列表，处理断点续传逻辑
    /// - Parameter files: 原始文件列表
    /// - Returns: 处理后的文件列表
    private func preprocessFilesForDownload(files: [NVEasyFileInfo]) -> [NVEasyFileInfo] {
        var processedFiles: [NVEasyFileInfo] = []
        
        for file in files {
            let fileSN = file.sn
            
            // 检查是否有可恢复的断点续传
            if let transferState = ResumeTransferManager.shared.getTransferState(fileSN: fileSN) as? ResumeTransferManager.TransferState,
               transferState.canResume {
                
                BLELogger.log("🔄 [断点续传] 文件 \(fileSN) 支持断点续传")
                BLELogger.log("  - 已下载: \(transferState.receivedBytes) / \(transferState.fileSize) 字节")
                BLELogger.log("  - 进度: \(transferState.progressString)")
                
                // 检查是否已有部分音频数据
                if let existingAudioData = AudioDataManager.shared.getFileAudioData(for: fileSN) {
                    BLELogger.log("🔄 [断点续传] 文件 \(fileSN) 已有音频数据: \(existingAudioData.count) 字节")
                    
                    // 基于传输进度判断数据一致性
                    let hasSignificantProgress = transferState.progress > 0.01 // 至少有1%的进度
                    let hasAudioData = existingAudioData.count > 0
                    
                    if hasSignificantProgress && hasAudioData {
                        BLELogger.log("✅ [断点续传] 文件 \(fileSN) 数据验证通过，准备续传")
                        BLELogger.log("  - 传输进度: \(transferState.progressString)")
                        BLELogger.log("  - 音频数据: \(existingAudioData.count) 字节")
                        processedFiles.append(file)
                    } else {
                        BLELogger.warning("⚠️ [断点续传] 文件 \(fileSN) 进度不足或没有音频数据，重新开始下载")
                        BLELogger.warning("  - 传输进度: \(transferState.progressString)")
                        BLELogger.warning("  - 音频数据: \(existingAudioData.count) 字节")
                        
                        // 清理数据，重新开始下载
                        AudioDataManager.shared.clearFileAudioData(for: fileSN)
                        ResumeTransferManager.shared.clearTransferState(fileSN: fileSN)
                        ResumeTransferManager.shared.startTransfer(file: file)
                        processedFiles.append(file)
                    }
                } else {
                    BLELogger.warning("⚠️ [断点续传] 文件 \(fileSN) 没有音频数据缓存，重新开始下载")
                    
                    // 清理传输状态，重新开始下载
                    ResumeTransferManager.shared.clearTransferState(fileSN: fileSN)
                    ResumeTransferManager.shared.startTransfer(file: file)
                    processedFiles.append(file)
                }
            } else {
                // 新文件，开始新的传输
                BLELogger.log("📁 [文件下载] 文件 \(fileSN) 开始新下载")
                ResumeTransferManager.shared.startTransfer(file: file)
                processedFiles.append(file)
            }
        }
        
        return processedFiles
    }
    
    /// 开始下载下一个文件
    private func startNextFileDownload() {
        // 检查是否还有文件需要下载
        guard self.currentDownloadIndex < self.pendingFiles.count else {
            BLELogger.success("✅ [文件传输管理] 所有文件下载完成")
            self.isDownloading = false
            self.currentDownloadIndex = 0
            return
        }
        
        // 获取当前要下载的文件
        let file = self.pendingFiles[self.currentDownloadIndex]
        let fileIndex = self.currentDownloadIndex + 1
        let totalFiles = self.pendingFiles.count
        
        BLELogger.log("📁 [文件传输管理] 开始下载文件 \(fileIndex)/\(totalFiles): SN=\(file.sn), 名称=\(file.name), 大小=\(file.size)")
        
        // 下载当前文件
        downloadSingleFileViaBluetooth(fileManager: NVFileManager.shared, file: file, index: fileIndex, total: totalFiles)
    }
    
    /// 文件下载完成后的回调处理
    func onFileDownloadComplete(success: Bool, fileSN: Int) {
        if success {
            BLELogger.success("✅ [文件传输管理] 文件 \(fileSN) 下载成功")
        } else {
            BLELogger.error("❌ [文件传输管理] 文件 \(fileSN) 下载失败")
        }
        
        // 移动到下一个文件
        self.currentDownloadIndex += 1
        
        // 延迟一小段时间后开始下载下一个文件，避免冲突
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startNextFileDownload()
        }
    }
    
    /// 下载单个文件，通过蓝牙
    /// - Parameters:
    ///   - fileManager: 文件管理器实例
    ///   - file: 要下载的文件信息
    ///   - index: 当前文件索引
    ///   - total: 总文件数
    private func downloadSingleFileViaBluetooth(fileManager: NVFileManager, file: NVEasyFileInfo, index: Int, total: Int) {
        BLELogger.log("📁 [文件传输管理] 开始下载文件 \(index)/\(total): \(file.name)")
        
        // 获取文件SN
        let fileSN = file.sn
        
        // 检查是否需要断点续传
        if let transferState = ResumeTransferManager.shared.getTransferState(fileSN: fileSN) as? ResumeTransferManager.TransferState,
           transferState.canResume {
            
            BLELogger.log("🔄 [断点续传] 文件 \(fileSN) 执行断点续传")
            BLELogger.log("  - 从字节 \(transferState.receivedBytes) 开始续传")
            BLELogger.log("  - 剩余字节: \(transferState.remainingBytes)")
            
            // 使用断点续传下载
            fileManager.downloadFile(sn: fileSN, offsetInBytes: transferState.receivedBytes)
            
        } else {
            BLELogger.log("📁 [文件下载] 文件 \(fileSN) 开始完整下载")
            
            // 开始新的传输（从头开始下载）
            fileManager.downloadFile(sn: fileSN)
        }
        
        BLELogger.log("📁 [文件传输管理] 已发起文件下载请求: \(file.name)")
    }
}

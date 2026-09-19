import Foundation
import NVEasySDK

/// 音频数据管理器
/// 负责管理BLE相关的音频数据存储和处理
class AudioDataManager: AudioDataManagerProtocol {
    
    // MARK: - Singleton
    
    static let shared = AudioDataManager()
    
    // MARK: - Properties
    
    /// 存储解码后的音频数据
    public var audioData: Data?
    
    /// 存储上次的音频数据
    public var lastAudioData: Data?
    
    /// 记录开始录音的时候会议卡片的模式
    public var lastCardMode: Int = 0
    
    // MARK: - 文件音频数据管理
    
    /// 为文件下载单独存储音频数据，避免不同文件之间的数据混淆
    private var fileAudioDataMap: [Int: Data] = [:]
    
    /// 音频数据存储路径
    private let audioDataPath: String = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(NVEasyConstants.FilePaths.audioDataPath).path
    }()
    
    /// 内存缓存大小限制（字节）
    private let maxMemoryCacheSize: Int = NVEasyConstants.MemoryLimits.maxFileAudioMemorySize
    
    /// 文件写入缓冲区大小（字节）
    private let writeBufferSize: Int = NVEasyConstants.MemoryLimits.fileWriteBufferSize
    
    /// 文件写入缓冲区
    private var fileWriteBuffers: [Int: Data] = [:]
    
    /// 文件写入缓冲区访问锁
    private let fileWriteBuffersLock = NSLock()
    
    // MARK: - Initialization
    
    private init() {
        setupAudioDataDirectory()
    }
    
    // MARK: - Public Methods
    
    /// 为指定文件初始化音频数据缓存
    func initFileAudioData(for fileSN: Int) {
        fileAudioDataMap[fileSN] = Data()
        fileWriteBuffers[fileSN] = Data()
        NVEasyLogger.info("📁 [音频数据管理] 为文件 \(fileSN) 初始化音频数据缓存")
    }
    
    /// 为指定文件添加音频数据
    func appendFileAudioData(_ data: Data, for fileSN: Int) {
        // 初始化缓存（如果不存在）
        if fileAudioDataMap[fileSN] == nil {
            fileAudioDataMap[fileSN] = Data()
        }
        if fileWriteBuffers[fileSN] == nil {
            fileWriteBuffers[fileSN] = Data()
        }
        
        // 添加数据
        fileAudioDataMap[fileSN]?.append(data)
        fileWriteBuffers[fileSN]?.append(data)
        
        // 检查是否需要写入文件
        if let bufferSize = fileWriteBuffers[fileSN]?.count, bufferSize >= writeBufferSize {
            flushBufferToFile(for: fileSN)
        }
        
        // 检查内存压力
        checkMemoryPressure()
    }
    
    /// 获取指定文件的音频数据
    func getFileAudioData(for fileSN: Int) -> Data? {
        // 先刷新缓冲区
        flushBufferToFile(for: fileSN)
        
        // 从文件读取完整数据
        let filePath = getAudioDataFilePath(for: fileSN)
        return try? Data(contentsOf: URL(fileURLWithPath: filePath))
    }
    
    /// 清理指定文件的音频数据
    func clearFileAudioData(for fileSN: Int) {
        fileAudioDataMap.removeValue(forKey: fileSN)
        fileWriteBuffers.removeValue(forKey: fileSN)
        
        // 删除文件
        let filePath = getAudioDataFilePath(for: fileSN)
        try? FileManager.default.removeItem(atPath: filePath)
        
        NVEasyLogger.info("📁 [音频数据管理] 清理文件 \(fileSN) 的音频数据")
    }
    
    /// 清理所有文件的音频数据
    func clearAllFileAudioData() {
        for fileSN in fileAudioDataMap.keys {
            clearFileAudioData(for: fileSN)
        }
        
        NVEasyLogger.info("📁 [音频数据管理] 清理所有文件音频数据")
    }
    
    /// 刷新所有缓冲区数据到文件
    func flushAllBuffersToFile(fileSN: Int) {
        flushBufferToFile(for: fileSN)
        NVEasyLogger.info("📁 [音频数据管理] 刷新文件 \(fileSN) 缓冲区到文件")
    }
    
    // MARK: - 实时音频流式处理（简化版本）
    
    /// 追加实时音频数据（简化实现）
    func appendRealtimeAudioData(_ data: Data) {
        // 简化实现：直接存储到audioData
        if audioData == nil {
            audioData = Data()
        }
        audioData?.append(data)
    }
    
    /// 获取实时音频数据
    func getRealtimeAudioData() -> Data? {
        return audioData
    }
    
    /// 清理实时音频流式处理资源
    func cleanupRealtimeAudioStream() {
        audioData = nil
        lastAudioData = nil
        NVEasyLogger.info("📁 [音频数据管理] 清理实时音频流式处理资源")
    }
    
    // MARK: - Private Methods
    
    private func setupAudioDataDirectory() {
        do {
            try FileManager.default.createDirectory(atPath: audioDataPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NVEasyLogger.error("❌ [音频数据管理] 创建音频数据目录失败: \(error)")
        }
    }
    
    private func getAudioDataFilePath(for fileSN: Int) -> String {
        return audioDataPath + "/file_\(fileSN)\(NVEasyConstants.FilePaths.pcmFileSuffix)"
    }
    
    private func flushBufferToFile(for fileSN: Int) {
        guard let bufferData = fileWriteBuffers[fileSN], !bufferData.isEmpty else { return }
        
        let filePath = getAudioDataFilePath(for: fileSN)
        let fileURL = URL(fileURLWithPath: filePath)
        
        do {
            if FileManager.default.fileExists(atPath: filePath) {
                // 追加到现有文件
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(bufferData)
                fileHandle.closeFile()
            } else {
                // 创建新文件
                try bufferData.write(to: fileURL)
            }
            
            // 清空缓冲区
            fileWriteBuffers[fileSN] = Data()
            
        } catch {
            NVEasyLogger.error("❌ [音频数据管理] 写入音频数据文件失败: \(error)")
        }
    }
    
    private func checkMemoryPressure() {
        let totalMemory = fileAudioDataMap.values.reduce(0) { $0 + $1.count }
        if totalMemory > maxMemoryCacheSize {
            NVEasyLogger.warning("⚠️ [音频数据管理] 内存压力过大，执行清理")
            // 清理一半的内存缓存
            let sortedFiles = fileAudioDataMap.sorted { $0.value.count > $1.value.count }
            let filesToClean = sortedFiles.prefix(sortedFiles.count / 2)
            
            for (fileSN, _) in filesToClean {
                flushBufferToFile(for: fileSN)
                fileAudioDataMap[fileSN] = Data()
            }
        }
    }
}

import Foundation

/// 实时音频流管理器
/// 负责管理实时音频数据的流式处理和内存优化
class RealtimeAudioStreamManager: RealtimeAudioStreamManagerProtocol {
    
    // MARK: - Singleton
    static let shared = RealtimeAudioStreamManager()
    
    // MARK: - Properties
    
    /// 实时音频文件句柄
    private var realtimeAudioFileHandle: FileHandle?
    
    /// 实时音频文件路径
    private var realtimeAudioFilePath: String?
    
    /// 最大实时内存大小
    private let maxRealtimeMemorySize = NVEasyConstants.MemoryLimits.maxRealtimeMemorySize
    
    /// 实时清理阈值
    private let realtimeCleanupThreshold = NVEasyConstants.MemoryLimits.realtimeCleanupThreshold
    
    /// 访问锁
    private let streamLock = NSLock()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 初始化实时音频数据流式处理
    func initRealtimeAudioStream() {
        // 创建实时音频数据文件
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        realtimeAudioFilePath = documentsPath.appendingPathComponent("realtime_audio_\(timestamp).data").path
        
        guard let filePath = realtimeAudioFilePath else {
            NVEasyLogger.error("❌ [实时音频流] 无法创建文件路径")
            return
        }
        
        do {
            // 创建文件
            FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
            
            // 打开文件句柄用于追加写入
            realtimeAudioFileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: filePath))
            realtimeAudioFileHandle?.seekToEndOfFile()
            
            NVEasyLogger.info("🔵 [实时音频流] 初始化流式处理，文件路径: \(filePath)")
        } catch {
            NVEasyLogger.error("❌ [实时音频流] 初始化失败: \(error)")
            realtimeAudioFileHandle = nil
            realtimeAudioFilePath = nil
        }
    }
    
    /// 追加实时音频数据到文件
    /// - Parameter data: 音频数据
    func appendRealtimeAudioData(_ data: Data) {
        // 如果文件句柄不存在，初始化流式处理
        if realtimeAudioFileHandle == nil {
            initRealtimeAudioStream()
        }
        
        // 写入数据到文件
        realtimeAudioFileHandle?.write(data)
        
        // 定期同步到磁盘（每1MB数据同步一次）
        if data.count % (1024 * 1024) == 0 {
            realtimeAudioFileHandle?.synchronizeFile()
        }
    }
    
    /// 检查实时音频内存压力
    /// - Parameter audioData: 当前音频数据
    /// - Returns: 处理后的音频数据
    func checkRealtimeMemoryPressure(_ audioData: Data) -> Data {
        var processedData = audioData
        
        // 如果内存缓存超过阈值，清理部分数据
        if processedData.count > realtimeCleanupThreshold {
            NVEasyLogger.warning("⚠️ [实时音频流] 内存压力检测，当前大小: \(processedData.count / 1024 / 1024)MB")
            
            // 保留最近的数据（1MB），清理旧数据
            let keepSize = 1024 * 1024
            if processedData.count > keepSize {
                let startIndex = processedData.count - keepSize
                processedData = processedData.subdata(in: startIndex..<processedData.count)
                
                NVEasyLogger.info("🧹 [实时音频流] 清理内存缓存，保留最近 \(keepSize / 1024)KB 数据")
            }
        }
        
        // 如果内存缓存超过最大限制，强制清理
        if processedData.count > maxRealtimeMemorySize {
            NVEasyLogger.warning("⚠️ [实时音频流] 内存缓存超过最大限制，强制清理")
            processedData = Data()
        }
        
        return processedData
    }
    
    /// 获取实时音频数据（从文件读取）
    /// - Returns: 完整的音频数据
    func getRealtimeAudioData() -> Data? {
        guard let filePath = realtimeAudioFilePath,
              FileManager.default.fileExists(atPath: filePath) else {
            NVEasyLogger.warning("⚠️ [实时音频流] 实时音频文件不存在")
            return nil
        }
        
        do {
            let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            NVEasyLogger.info("📁 [实时音频流] 从文件读取音频数据: \(fileData.count / 1024 / 1024)MB")
            return fileData
        } catch {
            NVEasyLogger.error("❌ [实时音频流] 读取音频文件失败: \(error)")
            return nil
        }
    }
    
    /// 清理实时音频流式处理资源
    func cleanupRealtimeAudioStream() {
        // 关闭文件句柄
        realtimeAudioFileHandle?.closeFile()
        realtimeAudioFileHandle = nil
        
        // 删除临时文件
        if let filePath = realtimeAudioFilePath {
            do {
                try FileManager.default.removeItem(atPath: filePath)
                NVEasyLogger.info("🧹 [实时音频流] 清理临时文件: \(filePath)")
            } catch {
                NVEasyLogger.error("❌ [实时音频流] 删除临时文件失败: \(error)")
            }
            realtimeAudioFilePath = nil
        }
    }
    
    /// 获取实时音频文件路径
    /// - Returns: 文件路径
    func getRealtimeAudioFilePath() -> String? {
        return realtimeAudioFilePath
    }
    
    /// 检查是否已初始化
    /// - Returns: 是否已初始化
    func isInitialized() -> Bool {
        return realtimeAudioFileHandle != nil
    }
}

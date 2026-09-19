import Foundation
import NVEasySDK
import opus
import AVFoundation

/// 音频处理委托管理器
/// 负责处理所有音频相关的回调事件
class AudioProcessingDelegateManager: AudioProcessingDelegateManagerProtocol {
    
    // MARK: - Singleton
    static let shared = AudioProcessingDelegateManager()
    
    // MARK: - Properties
    
    /// BLE管理器引用
    private weak var bleManager: BLEManager?
    
    /// 实时录音文件句柄
    private var opusFileHandle: FileHandle?
    private var pcmFileHandle: FileHandle?
    private var mp3FileHandle: FileHandle?
    
    /// 实时录音文件路径
    private var opusFilePath: String?
    private var pcmFilePath: String?
    private var mp3FilePath: String?
    
    /// 音频转换器
    private var audioConverter: AudioConverter?
    
    /// MP3编码缓冲区
    private var mp3Buffer: Data = Data()
    
    /// 是否已初始化MP3编码
    private var isMP3EncoderInitialized = false
    
    /// 边录制边转码的停止标志
    private var shouldStopStreaming = false
    
    // MARK: - Initialization
    
    private init() {}
    
    /// 设置BLE管理器引用
    func setBLEManager(_ bleManager: BLEManager) {
        self.bleManager = bleManager
    }
    
    // MARK: - Real-time Audio Callbacks
    
    /// 接收到 OPUS 编码的音频数据
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - opusData: OPUS 编码的音频数据
    ///   - framSize: 帧大小
    func handleRealTimeOPUSData(manager: NVEasyBLEManager, opusData: Data, framSize: Int32) {
        NVEasyLogger.info("🔵 [BLE实时流] 接收到OPUS数据 - 数据大小: \(opusData.count) bytes, 帧大小: \(framSize)")
        
        guard let bleManager = bleManager else {
            NVEasyLogger.error("❌ [BLE实时流] BLEManager引用丢失")
            return
        }
        
        // 1. 初始化实时录音文件（如果尚未创建）
        if opusFileHandle == nil {
            setupRealtimeRecordingFiles()
        }
        
        // 2. 检查当前录音模式
        let isMeeting = DeviceStatusDelegateManager.shared.isMeeting
        NVEasyLogger.info("🔵 [BLE实时流] 当前模式 - \(isMeeting ? "会议模式" : "通话模式")")
        
        // 记录音频参数用于调试
        let expectedChannels = isMeeting ? 1 : 2
        let expectedSampleRate = 16000
        NVEasyLogger.info("🔵 [BLE实时流] 音频参数 - 采样率: \(expectedSampleRate)Hz, 声道: \(expectedChannels)")
        
        // 3. 实时写入OPUS数据到文件
        writeOPUSDataToFile(opusData)
        
        // 4. 解码 OPUS 数据为 PCM
        func process(decodedData: Data?) {
            if let decodedData = decodedData {
                NVEasyLogger.info("🔵 [BLE实时流] OPUS解码成功 - PCM数据大小: \(decodedData.count) bytes")
                
                // 5. 实时写入PCM数据到文件
                writePCMDataToFile(decodedData)
                
                // 6. 实时转换PCM为MP3并写入文件
                convertAndWriteMP3Data(pcmData: decodedData)
            } else {
                NVEasyLogger.error("❌ [BLE实时流] OPUS解码失败")
            }
        }
        
        // 支持 80/40 帧分支
        if framSize == 80 {
            NVEasyLogger.info("🔵 [BLE实时流] 使用80帧解码器处理OPUS数据")
            NVOpusCodec.enqueueAudio80Data(toDecode: opusData) { decodedData in
                process(decodedData: decodedData)
            }
        } else {
            NVEasyLogger.info("🔵 [BLE实时流] 使用40帧解码器处理OPUS数据")
            NVOpusCodec.enqueueAudio40Data(toDecode: opusData) { decodedData in
                process(decodedData: decodedData)
            }
        }
    }
    
    // MARK: - Recording Status Callbacks
    
    /// 录音状态更新回调
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - action: 录音动作
    ///   - mode: 录音模式
    ///   - sampleRate: 采样率
    ///   - channels: 声道数
    ///   - recordType: 录音类型
    ///   - msDuration: 持续时间（毫秒）
    func handleRecordingStatusUpdate(manager: NVEasyBLEManager, action: NVEasyRecordAction, mode: NVEasyRecordMode, sampleRate: NVEasyRecordSampleRate, channels: Int, recordType: NVEasyRecordType, msDuration: UInt) {
        
        NVEasyLogger.info("🎤 [录音状态] 动作: \(action), 模式: \(mode), 采样率: \(sampleRate), 声道: \(channels), 类型: \(recordType)")
        
        guard let bleManager = bleManager else {
            NVEasyLogger.error("❌ [录音状态] BLEManager引用丢失")
            return
        }
        
        var status = 0
        var modeValue = mode == NVEasyRecordMode.meeting ? 0 : 1
        
        if DeviceStatusDelegateManager.shared.recordMode != mode {
            DeviceStatusDelegateManager.shared.recordMode = mode
            NVEasyPluginStreamHandler.shared.sendMeetingType(mode: mode.rawValue)
            
        }
        
        
        
        // 当录音停止时，处理录音文件
        if action == .stop {
            NVEasyLogger.info("🎤 [录音状态] 录音停止，处理录音文件")
            
            handleRecordStop(bleManager: bleManager, isMeeting: modeValue == 0)
            
            let arguments: [String: Any?] = [
                "status": status,
                "mode": modeValue
            ]
            NVEasyPlugin.methodChannel?.invokeMethod("sendRecordStatus", arguments: arguments)
            AudioProcessingDelegateManager.shared.stopRealtimeRecording()
        }
        
        if action == .start {
            status = 1
            NVEasyLogger.info("🎤 [录音状态] 录音开始")
            
            // 清理之前的录音状态和文件句柄
            cleanupPreviousRecordingState()
            
            // 设置录音开始时间
            bleManager.setRecordStartTime()
            
            let arguments: [String: Any?] = [
                "status": status,
                "mode": modeValue
            ]
            NVEasyPlugin.methodChannel?.invokeMethod("sendRecordStatus", arguments: arguments)
        }
    }
    
    // MARK: - Real-time Recording File Management
    
    /// 清理之前的录音状态和文件句柄
    private func cleanupPreviousRecordingState() {
        NVEasyLogger.info("🧹 [录音清理] 开始清理之前的录音状态")
        
        // 关闭所有文件句柄
        closeRealtimeRecordingFiles()
        
        // 重置文件路径
        opusFilePath = nil
        pcmFilePath = nil
        mp3FilePath = nil
        
        // 重置状态标志
        shouldStopStreaming = false
        isMP3EncoderInitialized = false
        
        NVEasyLogger.info("🧹 [录音清理] 录音状态清理完成")
    }
    
    /// 设置实时录音文件
    private func setupRealtimeRecordingFiles() {
        let timestamp = Int(Date().timeIntervalSince1970)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // 创建OPUS文件
        opusFilePath = documentsPath.appendingPathComponent("realtime_\(timestamp).opus").path
        // 创建PCM文件
        pcmFilePath = documentsPath.appendingPathComponent("realtime_\(timestamp).pcm").path
        // 创建MP3文件
        mp3FilePath = documentsPath.appendingPathComponent("realtime_\(timestamp).mp3").path
        
        do {
            // 创建OPUS文件句柄
            if let opusPath = opusFilePath {
                FileManager.default.createFile(atPath: opusPath, contents: nil, attributes: nil)
                opusFileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: opusPath))
                NVEasyLogger.info("📁 [实时录音] OPUS文件已创建: \(opusPath)")
            }
            
            // 创建PCM文件句柄
            if let pcmPath = pcmFilePath {
                FileManager.default.createFile(atPath: pcmPath, contents: nil, attributes: nil)
                pcmFileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: pcmPath))
                NVEasyLogger.info("📁 [实时录音] PCM文件已创建: \(pcmPath)")
            }
            
            // 创建MP3文件句柄
            if let mp3Path = mp3FilePath {
                FileManager.default.createFile(atPath: mp3Path, contents: nil, attributes: nil)
                mp3FileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: mp3Path))
                NVEasyLogger.info("📁 [实时录音] MP3文件已创建: \(mp3Path)")
            }
            
            NVEasyLogger.info("📁 [实时录音] 实时录音文件初始化完成")
            
        } catch {
            NVEasyLogger.error("❌ [实时录音] 创建文件失败: \(error)")
        }
    }
    
    /// 写入OPUS数据到文件
    private func writeOPUSDataToFile(_ opusData: Data) {
        
        guard let fileHandle = opusFileHandle else {
            NVEasyLogger.error("❌ [实时录音] OPUS文件句柄为空")
            return
        }
        
        do {
            fileHandle.write(opusData)
            NVEasyLogger.debug("📝 [实时录音] 已写入OPUS数据: \(opusData.count) bytes")
        } catch {
            NVEasyLogger.error("❌ [实时录音] 写入OPUS数据失败: \(error)")
        }
    }
    
    /// 写入PCM数据到文件
    private func writePCMDataToFile(_ pcmData: Data) {
        guard let fileHandle = pcmFileHandle else {
            NVEasyLogger.error("❌ [实时录音] PCM文件句柄为空")
            return
        }
        
        do {
            fileHandle.write(pcmData)
            NVEasyLogger.debug("📝 [实时录音] 已写入PCM数据: \(pcmData.count) bytes")
        } catch {
            NVEasyLogger.error("❌ [实时录音] 写入PCM数据失败: \(error)")
        }
    }
    
    /// 转换PCM数据为MP3并写入文件（流式实时转换）
    private func convertAndWriteMP3Data(pcmData: Data) {
        // 初始化音频转换器（如果尚未初始化）
        if audioConverter == nil {
            do {
                let isMeeting = DeviceStatusDelegateManager.shared.isMeeting
                let channels = 2
                audioConverter = try AudioConverter(sampleRate: 16000, channels: channels, bitrate: 128)
                isMP3EncoderInitialized = true
                NVEasyLogger.info("🎵 [实时MP3] 音频转换器已初始化 - 声道数: \(channels)")
            } catch {
                NVEasyLogger.error("❌ [实时MP3] 音频转换器初始化失败: \(error)")
                return
            }
        }
        
        guard let converter = audioConverter else {
            NVEasyLogger.error("❌ [实时MP3] 音频转换器为空")
            return
        }
        
        // 实时转换PCM数据为MP3数据
        do {
            let mp3Data = try converter.convertPCMDataToMP3Data(pcmData: pcmData)
            
            // 将MP3数据写入文件
            if let mp3Handle = mp3FileHandle {
                mp3Handle.write(mp3Data)
                NVEasyLogger.debug("📝 [实时MP3] 已写入MP3数据: \(mp3Data.count) bytes")
            }
            
        } catch {
            NVEasyLogger.error("❌ [实时MP3] PCM转MP3失败: \(error)")
        }
    }
    
    
    /// 关闭实时录音文件
    private func closeRealtimeRecordingFiles() {
        // 完成MP3编码
        finalizeMP3Encoding()
        
        // 关闭OPUS文件
        if let opusHandle = opusFileHandle {
            opusHandle.closeFile()
            opusFileHandle = nil
            NVEasyLogger.info("📁 [实时录音] OPUS文件已关闭")
        }
        
        // 关闭PCM文件
        if let pcmHandle = pcmFileHandle {
            pcmHandle.closeFile()
            pcmFileHandle = nil
            NVEasyLogger.info("📁 [实时录音] PCM文件已关闭")
        }
        
        // 关闭MP3文件
        if let mp3Handle = mp3FileHandle {
            mp3Handle.closeFile()
            mp3FileHandle = nil
            NVEasyLogger.info("📁 [实时录音] MP3文件已关闭")
        }
        
        // 清理音频转换器
        audioConverter = nil
        isMP3EncoderInitialized = false
        NVEasyLogger.info("🎵 [实时MP3] 音频转换器已清理")
    }
    
    /// 完成MP3编码（刷新编码器缓冲区）
    private func finalizeMP3Encoding() {
        guard let converter = audioConverter else {
            NVEasyLogger.info("🎵 [实时MP3] 音频转换器为空，无需刷新")
            return
        }
        
        // 刷新MP3编码器缓冲区，确保所有数据都被写入
        // 注意：这里不需要传入数据，只需要刷新编码器内部缓冲区
        do {
            // 调用编码器的刷新方法，获取剩余的编码数据
            let flushData = try converter.flushEncoder()
            if let mp3Handle = mp3FileHandle, !flushData.isEmpty {
                mp3Handle.write(flushData)
                NVEasyLogger.info("🎵 [实时MP3] 编码器缓冲区已刷新: \(flushData.count) bytes")
            }
        } catch {
            NVEasyLogger.error("❌ [实时MP3] 刷新编码器缓冲区失败: \(error)")
        }
        
        // 验证MP3文件
        if let mp3Path = mp3FilePath {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: mp3Path)
                let fileSize = attributes[.size] as? Int ?? 0
                NVEasyLogger.info("📊 [实时MP3] 最终MP3文件大小: \(fileSize) bytes")
            } catch {
                NVEasyLogger.error("❌ [实时MP3] 检查MP3文件失败: \(error)")
            }
        }
    }        
    
    
    /// 获取实时录音文件路径
    func getRealtimeRecordingFilePaths() -> [String: String] {
        var paths: [String: String] = [:]
        
        // 只返回MP3文件路径，因为OPUS和PCM文件已被清理
        if let mp3Path = mp3FilePath {
            paths["mp3"] = mp3Path
            NVEasyLogger.info("📁 [文件路径] 返回MP3文件路径: \(mp3Path)")
        }
        
        return paths
    }
    
    /// 手动停止实时录音
    func stopRealtimeRecording() {
        NVEasyLogger.info("🛑 [实时录音] 手动停止实时录音")
        
        // 设置停止标志
        shouldStopStreaming = true
        
        // 关闭实时录音文件
        closeRealtimeRecordingFiles()
        
        // 获取文件路径并发送到Flutter端
        let realtimeFilePaths = getRealtimeRecordingFilePaths()
        if !realtimeFilePaths.isEmpty {
            NVEasyLogger.info("📁 [实时录音] 实时录音文件路径: \(realtimeFilePaths)")
            NVEasyPlugin.methodChannel?.invokeMethod("didReceiveRealtimeRecordingFiles", arguments: realtimeFilePaths)
        }
        
        // 完全清理状态
        cleanupPreviousRecordingState()
    }
    
    /// 处理设备断开连接时的录音停止
    /// - Parameter isMeeting: 是否为会议模式
    func handleDeviceDisconnectionRecordStop(isMeeting: Bool) {
        NVEasyLogger.info("📱 [设备断开录音] 处理设备断开连接时的录音停止 isMeeting: \(isMeeting)")
        
        guard let bleManager = bleManager else {
            NVEasyLogger.error("❌ [设备断开录音] BLEManager引用丢失")
            return
        }
        
        // 调用录音停止处理逻辑
        handleRecordStop(bleManager: bleManager, isMeeting: isMeeting)
    }
    
    /// 检查是否正在实时录音
    func isRealtimeRecording() -> Bool {
        return opusFileHandle != nil || pcmFileHandle != nil || mp3FileHandle != nil
    }
    
    /// 清理文档目录中的临时音频文件
    func cleanupDocumentDirectoryTempFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        cleanupTempAudioFiles(in: documentsPath)
    }
    
    /// 强制清理所有录音资源（紧急清理）
    func forceCleanupAllRecordingResources() {
        NVEasyLogger.warning("⚠️ [紧急清理] 强制清理所有录音资源")
        
        // 设置停止标志
        shouldStopStreaming = true
        
        // 强制关闭所有文件句柄
        if let opusHandle = opusFileHandle {
            opusHandle.closeFile()
            opusFileHandle = nil
            NVEasyLogger.info("🧹 [紧急清理] OPUS文件句柄已强制关闭")
        }
        
        if let pcmHandle = pcmFileHandle {
            pcmHandle.closeFile()
            pcmFileHandle = nil
            NVEasyLogger.info("🧹 [紧急清理] PCM文件句柄已强制关闭")
        }
        
        if let mp3Handle = mp3FileHandle {
            mp3Handle.closeFile()
            mp3FileHandle = nil
            NVEasyLogger.info("🧹 [紧急清理] MP3文件句柄已强制关闭")
        }
        
        // 清理中间文件
        cleanupIntermediateFiles()
        
        // 清理所有状态
        cleanupPreviousRecordingState()
        
        NVEasyLogger.info("🧹 [紧急清理] 所有录音资源已强制清理完成")
    }
    
    // MARK: - Private Methods
    
    /// 处理录音停止事件
    private func handleRecordStop(bleManager: BLEManager, isMeeting: Bool) {
        NVEasyLogger.info("🎤 [录音处理] 开始处理录音停止事件 isMeeting: \(isMeeting)")
        
        // 检查是否已经处理过录音停止事件（防止重复处理）
        var isProcessingRecordStop = false
        if isProcessingRecordStop {
            NVEasyLogger.warning("⚠️ [录音处理] 录音停止事件正在处理中，跳过重复处理")
            return
        }
        isProcessingRecordStop = true
        
        // 删除中间文件（OPUS和PCM文件），只保留MP3文件
        cleanupIntermediateFiles()
        
        // 获取MP3文件时长
        if let mp3Path = self.mp3FilePath {
            let duration = self.getAudioDuration(filePath: mp3Path)
            
            // 发送MP3文件路径、时长和时间戳到Flutter端
            let arguments: [String: Any] = [
                "fileMp3Path": mp3Path,
                "fileDuration": duration,
                "scene": isMeeting == true ? 0 : 1,
                "recordStartTime": bleManager.getRecordStartTime() != nil ? bleManager.formatDateToString(bleManager.getRecordStartTime()!) : "未开始",
            ]
            NVEasyLogger.info("🎤 [录音处理] didReceiveRecordMP3FilePath: \(arguments)")
            NVEasyPlugin.methodChannel?.invokeMethod("didReceiveRecordMP3FilePath", arguments: arguments)
            
            NVEasyLogger.success("✅ [录音处理] 录音完成 - MP3路径: \(mp3Path), 时长: \(duration)秒")
        }
        
        // 清除录音开始时间
        bleManager.clearRecordStartTime()
        
        // 重置处理状态
        isProcessingRecordStop = false
        NVEasyBLEManager.shared.getFileList()
    }
    
    /// 获取音频文件时长
    private func getAudioDuration(filePath: String) -> Int {
        let url = URL(fileURLWithPath: filePath)
        
        do {
            let asset = AVAsset(url: url)
            let duration = asset.duration
            let durationInSeconds = CMTimeGetSeconds(duration)
            NVEasyLogger.info("⏱️ [音频时长] 文件: \(filePath), 时长: \(Int(durationInSeconds))秒")
            return Int(durationInSeconds)
        } catch {
            NVEasyLogger.error("❌ [音频时长] 获取音频时长失败: \(error)")
            return 0
        }
    }
    
    /// 清理中间文件（OPUS和PCM文件）
    private func cleanupIntermediateFiles() {
        NVEasyLogger.info("🧹 [文件清理] 开始清理中间文件")
        
        // 删除OPUS文件
        if let opusPath = opusFilePath {
            do {
                if FileManager.default.fileExists(atPath: opusPath) {
                    try FileManager.default.removeItem(atPath: opusPath)
                    NVEasyLogger.info("🗑️ [文件清理] OPUS文件已删除: \(opusPath)")
                }
            } catch {
                NVEasyLogger.error("❌ [文件清理] 删除OPUS文件失败: \(error)")
            }
        }
        
        // 删除PCM文件
        if let pcmPath = pcmFilePath {
            do {
                if FileManager.default.fileExists(atPath: pcmPath) {
                    try FileManager.default.removeItem(atPath: pcmPath)
                    NVEasyLogger.info("🗑️ [文件清理] PCM文件已删除: \(pcmPath)")
                }
            } catch {
                NVEasyLogger.error("❌ [文件清理] 删除PCM文件失败: \(error)")
            }
        }
        
        // 清理文件路径引用
        opusFilePath = nil
        pcmFilePath = nil
        
        NVEasyLogger.info("🧹 [文件清理] 中间文件清理完成")
    }
    
    /// 清理指定目录中的临时音频文件
    /// - Parameter directory: 目录路径
    private func cleanupTempAudioFiles(in directory: String) {
        NVEasyLogger.info("🧹 [批量清理] 开始清理目录中的临时音频文件: \(directory)")
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(atPath: directory)
            
            var deletedCount = 0
            var totalSize: Int64 = 0
            
            for fileName in contents {
                let filePath = "\(directory)/\(fileName)"
                
                // 检查是否为临时音频文件
                if fileName.hasPrefix("realtime_") && (fileName.hasSuffix(".opus") || fileName.hasSuffix(".pcm")) {
                    do {
                        // 获取文件大小
                        let attributes = try fileManager.attributesOfItem(atPath: filePath)
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        totalSize += fileSize
                        
                        // 删除文件
                        try fileManager.removeItem(atPath: filePath)
                        deletedCount += 1
                        NVEasyLogger.info("🗑️ [批量清理] 已删除临时文件: \(fileName)")
                    } catch {
                        NVEasyLogger.error("❌ [批量清理] 删除文件失败 \(fileName): \(error)")
                    }
                }
            }
            
            NVEasyLogger.info("🧹 [批量清理] 清理完成 - 删除文件数: \(deletedCount), 释放空间: \(formatFileSize(totalSize))")
            
        } catch {
            NVEasyLogger.error("❌ [批量清理] 读取目录失败: \(error)")
        }
    }
    
    /// 格式化文件大小
    /// - Parameter bytes: 字节数
    /// - Returns: 格式化后的文件大小字符串
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// 格式化日期时间字符串
    private func formatDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}

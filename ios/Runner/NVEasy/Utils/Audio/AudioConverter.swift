import Foundation
import AVFoundation

// LAME库类型声明
typealias lame_global_flags = OpaquePointer

/// 音频转换器工具类
/// 提供PCM到MP3的转换功能
class AudioConverter {
    
    // MARK: - Constants
    
    private static let PCM_BUFFER_SIZE = 576
    private static let MP3_BUFFER_SIZE = 4096
    private static let FLUSH_BUFFER_SIZE = 16384
    private static let MAX_SAMPLE_VALUE: Int16 = 32767
    private static let MIN_SAMPLE_VALUE: Int16 = -32768
    
    // MARK: - Properties
    
    private let gfp: lame_global_flags
    private let sampleRate: Int
    private let channels: Int
    private let bitrate: Int32
    
    // 线程安全锁
    private let encodingLock = NSLock()
    
    // 编码器状态
    private var isEncoderInitialized = false
    private var lastError: AudioConversionError?
    
    // MARK: - Initialization
    
    /// 初始化音频转换器
    /// - Parameters:
    ///   - sampleRate: 采样率（默认16000）
    ///   - channels: 声道数（默认2）
    ///   - bitrate: 比特率（默认128）
    /// - Throws: 初始化失败时抛出错误
    init(sampleRate: Int = NVEasyConstants.AudioSettings.defaultSampleRate,
         channels: Int = NVEasyConstants.AudioSettings.defaultChannels,
         bitrate: Int32 = 128) throws {
        
        guard let gfp = lame_init() else {
            throw AudioConversionError.lameInitializationFailed
        }
        
        self.gfp = gfp
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitrate = bitrate
        
        try configureLAME()
        isEncoderInitialized = true
    }
    
    deinit {
        encodingLock.lock()
        defer { encodingLock.unlock() }
        lame_close(gfp)
        isEncoderInitialized = false
    }
    
    // MARK: - Configuration
    
    /// 配置LAME参数
    private func configureLAME() throws {
        // 设置采样率
        if lame_set_in_samplerate(gfp, Int32(sampleRate)) != 0 {
            throw AudioConversionError.lameConfigurationFailed("设置输入采样率失败")
        }
        
        lame_set_out_samplerate(gfp, Int32(sampleRate))
        
        // 设置声道数
        if lame_set_num_channels(gfp, Int32(channels)) != 0 {
            throw AudioConversionError.lameConfigurationFailed("设置声道数失败")
        }
        
        // 设置比特率
        if lame_set_brate(gfp, bitrate) != 0 {
            throw AudioConversionError.lameConfigurationFailed("设置比特率失败")
        }
        
        // 设置质量（使用更保守的设置）
        if lame_set_quality(gfp, 5) != 0 {
            throw AudioConversionError.lameConfigurationFailed("设置质量失败")
        }
        
        // 设置模式
        if channels == 1 {
            lame_set_mode(gfp, MONO)
        } else {
            lame_set_mode(gfp, STEREO)
        }
        
        // 禁用VBR
        lame_set_VBR(gfp, vbr_off)
        
        // 禁用ID3标签
        lame_set_write_id3tag_automatic(gfp, 0)
        
        // 设置更保守的编码参数，避免断言错误
        lame_set_analysis(gfp, 1)  // 启用分析
        lame_set_bWriteVbrTag(gfp, 0)  // 禁用VBR标签
        
        // 设置帧大小限制，避免断言错误
        if sampleRate == 16000 {
            lame_set_force_ms(gfp, 0)  // 不强制单声道
        }
        
        // 设置缓冲区大小，避免缓冲区不一致错误
        // 注意：某些LAME版本可能不支持这些优化设置，使用更保守的方法
        // lame_set_asm_optimizations(gfp, Int32(MMX.rawValue), 1)  // 启用MMX优化
        // lame_set_asm_optimizations(gfp, Int32(SSE.rawValue), 1)  // 启用SSE优化
        
        // 设置更保守的缓冲区参数
        lame_set_highpassfreq(gfp, 0)  // 禁用高通滤波器
        lame_set_lowpassfreq(gfp, 0)   // 禁用低通滤波器
        
        // 设置缓冲区大小限制
        lame_set_scale(gfp, 1.0)  // 设置缩放因子
        
        // 初始化参数
        if lame_init_params(gfp) != 0 {
            throw AudioConversionError.lameConfigurationFailed("初始化LAME参数失败")
        }
    }
    
    // MARK: - PCM File to MP3 File Conversion
    
    /// 将PCM文件转换为MP3文件
    /// - Parameters:
    ///   - pcmFilePath: PCM文件路径
    ///   - mp3FilePath: 输出MP3文件路径
    /// - Returns: 是否转换成功
    func convertPCMFileToMP3File(pcmFilePath: String, mp3FilePath: String) -> Bool {
        guard FileManager.default.fileExists(atPath: pcmFilePath) else {
            NVEasyLogger.error("PCM文件不存在: \(pcmFilePath)")
            return false
        }
        
        do {
            // 读取PCM文件数据
            let pcmData = try Data(contentsOf: URL(fileURLWithPath: pcmFilePath))
            
            // 转换为MP3数据
            let mp3Data = try convertPCMDataToMP3Data(pcmData: pcmData)
            
            // 写入MP3文件
            try mp3Data.write(to: URL(fileURLWithPath: mp3FilePath))
            
            NVEasyLogger.info("PCM文件转MP3成功: \(pcmFilePath) -> \(mp3FilePath)")
            return true
            
        } catch {
            NVEasyLogger.error("PCM文件转MP3失败: \(error)")
            return false
        }
    }
    
    /// 异步将PCM文件转换为MP3文件
    /// - Parameters:
    ///   - pcmFilePath: PCM文件路径
    ///   - mp3FilePath: 输出MP3文件路径
    ///   - completion: 完成回调
    func convertPCMFileToMP3FileAsync(pcmFilePath: String, 
                                    mp3FilePath: String, 
                                    completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = self.convertPCMFileToMP3File(pcmFilePath: pcmFilePath, mp3FilePath: mp3FilePath)
            DispatchQueue.main.async {
                completion(success, success ? nil : AudioConversionError.fileOperationFailed("转换失败"))
            }
        }
    }
    
    // MARK: - Data Validation
    
    /// 验证PCM数据格式
    /// - Parameter pcmData: PCM数据
    /// - Returns: 是否有效
    private func validatePCMData(_ pcmData: Data) -> Bool {
        // 检查数据长度
        guard pcmData.count > 0 else { return false }
        guard pcmData.count % 2 == 0 else { return false }  // 16位PCM必须是偶数字节
        
        // 检查数据范围（避免全零或异常值）
        let sampleCount = pcmData.count / 2
        guard sampleCount > 0 else { return false }
        
        // 检查是否有有效的音频数据（不是全零）
        let hasNonZeroData = pcmData.withUnsafeBytes { bytes in
            let int16Bytes = bytes.bindMemory(to: Int16.self)
            return int16Bytes.contains { $0 != 0 }
        }
        
        return hasNonZeroData
    }
    
    /// 高效处理PCM数据，避免重复分配内存
    /// - Parameters:
    ///   - pcmData: PCM数据
    ///   - startIndex: 开始索引
    ///   - count: 处理数量
    /// - Returns: 处理后的声道数据
    private func processPCMDataEfficiently(_ pcmData: Data, startIndex: Int, count: Int) -> ([Int16], [Int16]) {
        let endIndex = min(startIndex + count, pcmData.count)
        let actualCount = endIndex - startIndex
        
        guard actualCount > 0 && actualCount % 2 == 0 else {
            return ([], [])
        }
        
        let pcmInt16Array = pcmData.withUnsafeBytes { bytes in
            let startPtr = bytes.baseAddress!.advanced(by: startIndex)
            let int16Ptr = startPtr.bindMemory(to: Int16.self, capacity: actualCount / 2)
            return Array(UnsafeBufferPointer(start: int16Ptr, count: actualCount / 2))
        }
        
        var leftChannel = [Int16]()
        var rightChannel = [Int16]()
        
        if channels == 1 {
            // 单声道：所有数据都作为左声道
            leftChannel = pcmInt16Array
            rightChannel = pcmInt16Array
        } else {
            // 立体声：交错格式 LRLRLR...
            let stereoCount = (pcmInt16Array.count / 2) * 2
            leftChannel.reserveCapacity(stereoCount / 2)
            rightChannel.reserveCapacity(stereoCount / 2)
            
            for i in stride(from: 0, to: stereoCount, by: 2) {
                leftChannel.append(pcmInt16Array[i])
                rightChannel.append(pcmInt16Array[i + 1])
            }
        }
        
        return (leftChannel, rightChannel)
    }
    
    // MARK: - PCM Data to MP3 Data Conversion
    
    /// 预处理音频数据，确保格式正确
    /// - Parameters:
    ///   - leftChannel: 左声道数据
    ///   - rightChannel: 右声道数据
    /// - Returns: 预处理后的声道数据
    private func preprocessAudioData(leftChannel: [Int16], rightChannel: [Int16]) -> ([Int16], [Int16]) {
        var processedLeft = leftChannel
        var processedRight = rightChannel
        
        // 确保声道数据长度一致
        let minLength = min(processedLeft.count, processedRight.count)
        if minLength > 0 {
            processedLeft = Array(processedLeft.prefix(minLength))
            processedRight = Array(processedRight.prefix(minLength))
        }
        
        // 检查并修复可能的异常值
        for i in 0..<processedLeft.count {
            // 限制样本值在有效范围内
            processedLeft[i] = max(Self.MIN_SAMPLE_VALUE, min(Self.MAX_SAMPLE_VALUE, processedLeft[i]))
            processedRight[i] = max(Self.MIN_SAMPLE_VALUE, min(Self.MAX_SAMPLE_VALUE, processedRight[i]))
        }
        
        return (processedLeft, processedRight)
    }
    
    /// 检查编码器状态
    private func checkEncoderState() throws {
        guard isEncoderInitialized else {
            throw AudioConversionError.lameConfigurationFailed("编码器未初始化")
        }
        
        if let error = lastError {
            throw error
        }
    }
    
    /// 重置LAME编码器内部状态（仅在必要时调用）
    private func resetLAMEStateIfNeeded() {
        // 只在检测到错误时才重置，避免频繁调用
        guard lastError != nil else { return }
        
        lame_set_scale(gfp, 1.0)
        lame_set_highpassfreq(gfp, 0)
        lame_set_lowpassfreq(gfp, 0)
        lastError = nil
    }
    
    /// 安全编码方法，优化版本
    /// - Parameters:
    ///   - leftChannel: 左声道数据
    ///   - rightChannel: 右声道数据
    ///   - sampleCount: 样本数量
    ///   - mp3Buffer: MP3缓冲区
    ///   - bufferSize: 缓冲区大小
    /// - Returns: 编码字节数，负数表示错误
    private func safeEncodeBuffer(leftChannel: [Int16], 
                                 rightChannel: [Int16], 
                                 sampleCount: Int32, 
                                 mp3Buffer: inout [UInt8], 
                                 bufferSize: Int32) -> Int32 {
        // 验证输入参数
        guard sampleCount > 0 && sampleCount <= Int32(leftChannel.count) && sampleCount <= Int32(rightChannel.count) else {
            NVEasyLogger.error("🚨 [LAME编码] 无效的输入参数: sampleCount=\(sampleCount), leftCount=\(leftChannel.count), rightCount=\(rightChannel.count)")
            lastError = AudioConversionError.encodingFailed
            return -1
        }
        
        // 只在必要时重置状态
        resetLAMEStateIfNeeded()
        
        // 执行编码
        let result = lame_encode_buffer(
            gfp,
            leftChannel,
            rightChannel,
            sampleCount,
            &mp3Buffer,
            bufferSize
        )
        
        // 记录错误状态
        if result < 0 {
            lastError = AudioConversionError.encodingFailed
        }
        
        return result
    }
    
    /// 将PCM数据转换为MP3数据（流式编码，不刷新缓冲区）
    /// - Parameter pcmData: PCM数据
    /// - Returns: 转换后的MP3数据
    func convertPCMDataToMP3Data(pcmData: Data) throws -> Data {
        // 线程安全保护
        encodingLock.lock()
        defer { encodingLock.unlock() }
        
        // 检查编码器状态
        try checkEncoderState()
        
        guard !pcmData.isEmpty else {
            throw AudioConversionError.invalidAudioData
        }
        
        // 验证PCM数据格式
        guard validatePCMData(pcmData) else {
            throw AudioConversionError.invalidAudioData
        }
        
        var mp3Data = Data()
        var mp3Buffer = [UInt8](repeating: 0, count: Self.MP3_BUFFER_SIZE)
        
        let totalBytes = pcmData.count
        var processedBytes = 0
        
        while processedBytes < totalBytes {
            let remainingBytes = totalBytes - processedBytes
            let bytesToProcess = min(Self.PCM_BUFFER_SIZE * 2, remainingBytes) // 每个样本2字节
            
            if bytesToProcess == 0 {
                break
            }
            
            // 使用高效方法处理PCM数据
            let (leftChannel, rightChannel) = processPCMDataEfficiently(
                pcmData, 
                startIndex: processedBytes, 
                count: bytesToProcess
            )
            
            // 确保左右声道长度一致，避免LAME断言错误
            let minLength = min(leftChannel.count, rightChannel.count)
            if minLength > 0 {
                let leftFinal = Array(leftChannel.prefix(minLength))
                let rightFinal = Array(rightChannel.prefix(minLength))
                
                // 添加额外的数据验证
                guard minLength > 0 && minLength <= Int32.max else {
                    NVEasyLogger.warning("⚠️ [LAME编码] 无效的样本长度: \(minLength)")
                    processedBytes += bytesToProcess
                    continue
                }
                
                // 验证声道数据不为空
                guard !leftFinal.isEmpty && !rightFinal.isEmpty else {
                    NVEasyLogger.warning("⚠️ [LAME编码] 声道数据为空")
                    processedBytes += bytesToProcess
                    continue
                }
                
                // 预处理音频数据
                let (processedLeft, processedRight) = preprocessAudioData(leftChannel: leftFinal, rightChannel: rightFinal)
                
                // 使用安全编码方法
                let encodedBytes = safeEncodeBuffer(
                    leftChannel: processedLeft,
                    rightChannel: processedRight,
                    sampleCount: Int32(processedLeft.count),
                    mp3Buffer: &mp3Buffer,
                    bufferSize: Int32(Self.MP3_BUFFER_SIZE)
                )
                
                if encodedBytes > 0 {
                    mp3Data.append(Data(bytes: mp3Buffer, count: Int(encodedBytes)))
                } else if encodedBytes < 0 {
                    // LAME返回负值表示错误，跳过这个数据块
                    NVEasyLogger.warning("⚠️ [LAME编码] 编码失败，跳过数据块: \(encodedBytes)")
                    
                    // 记录错误但不立即重置，避免频繁重置
                    if encodedBytes == -1 {
                        NVEasyLogger.warning("⚠️ [LAME编码] 检测到缓冲区错误")
                    }
                }
            }
            
            processedBytes += bytesToProcess
        }
        
        // 注意：流式编码时不刷新缓冲区，留到最终刷新时处理
        return mp3Data
    }
    
    /// 刷新编码器缓冲区
    /// - Returns: 刷新后的MP3数据
    func flushEncoder() throws -> Data {
        // 线程安全保护
        encodingLock.lock()
        defer { encodingLock.unlock() }
        
        // 检查编码器状态
        try checkEncoderState()
        
        var mp3Buffer = [UInt8](repeating: 0, count: Self.FLUSH_BUFFER_SIZE)
        var mp3Data = Data()
        
        // 刷新编码器
        let flushBytes = lame_encode_flush(gfp, &mp3Buffer, Int32(Self.FLUSH_BUFFER_SIZE))
        if flushBytes > 0 {
            mp3Data.append(Data(bytes: mp3Buffer, count: Int(flushBytes)))
        }
        
        return mp3Data
    }
    
    /// 异步将PCM数据转换为MP3数据
    /// - Parameters:
    ///   - pcmData: PCM数据
    ///   - completion: 完成回调
    func convertPCMDataToMP3DataAsync(pcmData: Data, 
                                    completion: @escaping (Data?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let mp3Data = try self.convertPCMDataToMP3Data(pcmData: pcmData)
                DispatchQueue.main.async {
                    completion(mp3Data, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    /// 重置编码器状态，用于错误恢复
    func resetEncoder() {
        encodingLock.lock()
        defer { encodingLock.unlock() }
        
        lastError = nil
        resetLAMEStateIfNeeded()
        NVEasyLogger.info("🔄 [LAME编码] 编码器状态已重置")
    }
    
    /// 获取编码器状态信息
    var encoderStatus: String {
        encodingLock.lock()
        defer { encodingLock.unlock() }
        
        let status = isEncoderInitialized ? "已初始化" : "未初始化"
        let errorInfo = lastError?.localizedDescription ?? "无错误"
        return "编码器状态: \(status), 最后错误: \(errorInfo)"
    }
    
    // MARK: - Static Methods
    
    /// 创建音频转换器实例
    /// - Parameters:
    ///   - sampleRate: 采样率
    ///   - channels: 声道数
    ///   - bitrate: 比特率
    /// - Returns: 音频转换器实例
    static func create(sampleRate: Int = NVEasyConstants.AudioSettings.defaultSampleRate,
                      channels: Int = NVEasyConstants.AudioSettings.defaultChannels,
                      bitrate: Int32 = 128) throws -> AudioConverter {
        return try AudioConverter(sampleRate: sampleRate, channels: channels, bitrate: bitrate)
    }
    
    /// 快速转换PCM文件为MP3文件
    /// - Parameters:
    ///   - pcmFilePath: PCM文件路径
    ///   - mp3FilePath: 输出MP3文件路径
    ///   - sampleRate: 采样率
    ///   - channels: 声道数
    ///   - bitrate: 比特率
    /// - Returns: 是否转换成功
    static func convertPCMFileToMP3File(pcmFilePath: String,
                                       mp3FilePath: String,
                                       sampleRate: Int = NVEasyConstants.AudioSettings.defaultSampleRate,
                                       channels: Int = NVEasyConstants.AudioSettings.defaultChannels,
                                       bitrate: Int32 = 128) -> Bool {
        do {
            let converter = try AudioConverter(sampleRate: sampleRate, channels: channels, bitrate: bitrate)
            return converter.convertPCMFileToMP3File(pcmFilePath: pcmFilePath, mp3FilePath: mp3FilePath)
        } catch {
            NVEasyLogger.error("创建音频转换器失败: \(error)")
            return false
        }
    }
    
    /// 快速转换PCM数据为MP3数据
    /// - Parameters:
    ///   - pcmData: PCM数据
    ///   - sampleRate: 采样率
    ///   - channels: 声道数
    ///   - bitrate: 比特率
    /// - Returns: 转换后的MP3数据，失败返回nil
    static func convertPCMDataToMP3Data(pcmData: Data,
                                       sampleRate: Int = NVEasyConstants.AudioSettings.defaultSampleRate,
                                       channels: Int = NVEasyConstants.AudioSettings.defaultChannels,
                                       bitrate: Int32 = 128) -> Data? {
        do {
            let converter = try AudioConverter(sampleRate: sampleRate, channels: channels, bitrate: bitrate)
            return try converter.convertPCMDataToMP3Data(pcmData: pcmData)
        } catch {
            NVEasyLogger.error("创建音频转换器失败: \(error)")
            return nil
        }
    }
    
    /// 异步快速转换PCM文件为MP3文件
    /// - Parameters:
    ///   - pcmFilePath: PCM文件路径
    ///   - mp3FilePath: 输出MP3文件路径
    ///   - sampleRate: 采样率
    ///   - channels: 声道数
    ///   - bitrate: 比特率
    ///   - completion: 完成回调
    static func convertPCMFileToMP3FileAsync(pcmFilePath: String,
                                            mp3FilePath: String,
                                            sampleRate: Int = NVEasyConstants.AudioSettings.defaultSampleRate,
                                            channels: Int = NVEasyConstants.AudioSettings.defaultChannels,
                                            bitrate: Int32 = 128,
                                            completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = convertPCMFileToMP3File(pcmFilePath: pcmFilePath, 
                                                mp3FilePath: mp3FilePath, 
                                                sampleRate: sampleRate, 
                                                channels: channels, 
                                                bitrate: bitrate)
            DispatchQueue.main.async {
                completion(success, success ? nil : AudioConversionError.fileOperationFailed("转换失败"))
            }
        }
    }
    
    /// 异步快速转换PCM数据为MP3数据
    /// - Parameters:
    ///   - pcmData: PCM数据
    ///   - sampleRate: 采样率
    ///   - channels: 声道数
    ///   - bitrate: 比特率
    ///   - completion: 完成回调
    static func convertPCMDataToMP3DataAsync(pcmData: Data,
                                            sampleRate: Int = NVEasyConstants.AudioSettings.defaultSampleRate,
                                            channels: Int = NVEasyConstants.AudioSettings.defaultChannels,
                                            bitrate: Int32 = 128,
                                            completion: @escaping (Data?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let mp3Data = convertPCMDataToMP3Data(pcmData: pcmData, 
                                                sampleRate: sampleRate, 
                                                channels: channels, 
                                                bitrate: bitrate)
            DispatchQueue.main.async {
                completion(mp3Data, mp3Data != nil ? nil : AudioConversionError.encodingFailed)
            }
        }
    }
}

// MARK: - Audio Conversion Errors

/// 音频转换错误类型
enum AudioConversionError: Error, LocalizedError {
    case lameInitializationFailed
    case lameConfigurationFailed(String)
    case fileOperationFailed(String)
    case invalidAudioData
    case encodingFailed
    
    var errorDescription: String? {
        switch self {
        case .lameInitializationFailed:
            return "LAME编码器初始化失败"
        case .lameConfigurationFailed(let message):
            return "LAME配置失败: \(message)"
        case .fileOperationFailed(let message):
            return "文件操作失败: \(message)"
        case .invalidAudioData:
            return "无效的音频数据"
        case .encodingFailed:
            return "音频编码失败"
        }
    }
}

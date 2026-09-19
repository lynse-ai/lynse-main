import Foundation
import NVEasySDK
import AVFoundation
import opus

/// 文件传输委托管理器
/// 负责处理所有文件传输相关的回调事件
class FileTransferDelegateManager: FileTransferDelegateManagerProtocol {
    
    // MARK: - Singleton
    static let shared = FileTransferDelegateManager()
    
    // MARK: - Properties
    
    /// BLE管理器引用
    private weak var bleManager: BLEManager?
    
    /// 访问锁
    private let transferLock = NSLock()
    
    /// 文件传输音频转换器缓存
    private var fileAudioConverters: [Int: AudioConverter] = [:]
    
    /// 文件传输MP3文件句柄缓存
    private var fileMP3Handles: [Int: FileHandle] = [:]
    
    /// 文件传输MP3文件路径缓存
    private var fileMP3Paths: [Int: String] = [:]
    
    /// 文件信息缓存 - 缓存所有文件属性，使用文件名作为key
    private var fileInfoCache: [String: NVEasyFileInfo] = [:]
    
    // MARK: - Initialization
    
    private init() {}
    
    /// 设置BLE管理器引用
    func setBLEManager(_ bleManager: BLEManager) {
        self.bleManager = bleManager
    }
    
    /// 手动启动文件下载
    /// - Parameter files: 要下载的文件列表
    func startDownloadFiles(_ files: [NVEasyFileInfo]) {
        NVEasyLogger.info("📁 [文件下载] 手动启动文件下载，共 \(files.count) 个文件")
        
        // 缓存文件信息
        for file in files {
            fileInfoCache[file.name] = file
            checkResumeTransferForFile(file: file)
        }
        
        // 开始下载
        startFileDownload(files: files)
    }
    
    /// 停止文件下载
    func stopFileDownload() {
        NVEasyLogger.info("📁 [文件下载] 停止文件下载")
        
        // 清理所有文件传输资源
        for (fileName, fileInfo) in fileInfoCache {
            cleanupFileTransferResources(fileSN: fileInfo.sn)
        }
        
        // 清理文件信息缓存
        fileInfoCache.removeAll()
    }
    
    /// 获取当前下载状态
    /// - Returns: 下载状态信息
    func getDownloadStatus() -> (isDownloading: Bool, currentFile: Int, totalFiles: Int) {
        let downloadProgress = FileTransferManager.shared.getDownloadProgress()
        return (
            isDownloading: downloadProgress.isDownloading,
            currentFile: downloadProgress.current,
            totalFiles: downloadProgress.total
        )
    }
    
    // MARK: - Bluetooth File Transfer Callbacks
    
    /// 蓝牙文件传输完成回调
    /// - Parameters:
    ///   - manager: 文件管理器实例
    ///   - isFinish: 是否完成
    ///   - fileSN: 文件序列号
    ///   - error: 错误信息（如果有）
    func handleBluetoothFileTransferFinish(manager: NVEasyFileManager, isFinish: Bool, fileSN: Int, error: Error?) {
        NVEasyLogger.info("📁 [蓝牙文件传输] 文件 \(fileSN) 传输完成: \(isFinish), 错误: \(error?.localizedDescription ?? "无")")
        
        guard let bleManager = bleManager else {
            NVEasyLogger.error("❌ [蓝牙文件传输] BLEManager引用丢失")
            return
        }
        
        if isFinish {
            // 传输成功处理
            handleBluetoothTransferSuccess(bleManager: bleManager, fileSN: fileSN)
        } else {
            // 传输失败处理
            handleBluetoothTransferFailure(bleManager: bleManager, fileSN: fileSN, error: error)
        }
        
        // 清理速度计算缓存
        bleManager.clearSpeedCalculation(for: fileSN)
    }
    
    /// 蓝牙文件传输过程中接收到 OPUS 数据
    /// - Parameters:
    ///   - manager: 文件管理器实例
    ///   - opusData: OPUS 编码的音频数据
    ///   - fileSN: 文件序列号
    ///   - totalPkgCount: 总包数
    ///   - pkgNum: 当前包号
    func handleBluetoothFileTransferData(manager: NVEasyFileManager, opusData: Data, fileSN: Int, totalPkgCount: Int, pkgNum: Int) {
        NVEasyLogger.info("📁 [蓝牙文件传输] 文件 \(fileSN) 接收到OPUS数据 - 包 \(pkgNum)/\(totalPkgCount), 数据大小: \(opusData.count) bytes")
        
        guard let bleManager = bleManager else {
            NVEasyLogger.error("❌ [蓝牙文件传输] BLEManager引用丢失")
            return
        }
        
        // 验证数据有效性
        guard !opusData.isEmpty else {
            NVEasyLogger.error("❌ [蓝牙文件传输] 文件 \(fileSN) 接收到空数据")
            return
        }
        
        // 1. 处理断点续传逻辑
        let transferInfo = processResumeTransferLogic(fileSN: fileSN, pkgNum: pkgNum, totalPkgCount: totalPkgCount)
        
        // 2. 初始化文件传输（仅第一个包）
        if pkgNum == 1 && !transferInfo.isResumeTransfer {
            initializeFileTransfer(bleManager: bleManager, fileSN: fileSN, totalPkgCount: totalPkgCount)
        }
        
        // 3. 更新传输进度
        updateTransferProgress(fileSN: fileSN, actualPacketNumber: transferInfo.actualPacketNumber, totalPackets: transferInfo.displayTotalPackets, dataSize: opusData.count)
        
        // 4. 更新速度计算
        updateSpeedCalculation(bleManager: bleManager, fileSN: fileSN, pkgNum: pkgNum, dataSize: opusData.count)
        
        // 5. 处理OPUS数据解码
        processOPUSData(bleManager: bleManager, opusData: opusData, fileSN: fileSN, pkgNum: pkgNum, actualPacketNumber: transferInfo.actualPacketNumber, displayTotalPackets: transferInfo.displayTotalPackets)
    }
    
    // MARK: - WiFi File Transfer Callbacks
    
    /// WiFi文件传输完成回调
    /// - Parameters:
    ///   - manager: 文件管理器实例
    ///   - isFinish: 是否完成
    ///   - fileSN: 文件序列号
    ///   - error: 错误信息（如果有）
    func handleWiFiFileTransferFinish(manager: NVEasyFileManager, isFinish: Bool, fileSN: Int, error: Error?) {
        NVEasyLogger.info("📁 [WiFi文件传输] 文件 \(fileSN) 传输完成: \(isFinish), 错误: \(error?.localizedDescription ?? "无")")
        
        // WiFi传输完成处理逻辑
        // 可以根据需要实现WiFi特定的处理逻辑
    }
    
    /// WiFi文件传输过程中接收到 OPUS 数据
    /// - Parameters:
    ///   - manager: 文件管理器实例
    ///   - opusData: OPUS 编码的音频数据
    ///   - fileSN: 文件序列号
    ///   - totalPkgCount: 总包数
    ///   - pkgNum: 当前包号
    func handleWiFiFileTransferData(manager: NVEasyFileManager, opusData: Data, fileSN: Int, totalPkgCount: Int, pkgNum: Int) {
        NVEasyLogger.info("📁 [WiFi文件传输] 文件 \(fileSN) 接收到OPUS数据 - 包 \(pkgNum)/\(totalPkgCount), 数据大小: \(opusData.count) bytes")
        
        // WiFi传输数据处理逻辑
        // 可以根据需要实现WiFi特定的处理逻辑
    }
    
    // MARK: - File List Callbacks
    
    /// 接收到设备文件列表
    /// - Parameters:
    ///   - manager: 文件管理器实例
    ///   - files: 文件信息数组
    func handleFileListReceived(manager: NVEasyFileManager, files: [NVEasyFileInfo]) {
        NVEasyLogger.info("📁 [文件列表] 接收到 \(files.count) 个文件:")
        for file in files {
            NVEasyLogger.info("  - SN: \(file.sn), 名称: \(file.name), 大小: \(file.size), 场景: \(file.scene), 开始: \(file.startTimestamp), 结束: \(file.endTimestamp)")
            
            // 缓存完整的文件信息
            fileInfoCache[file.name] = file
            
            // 检查是否支持断点续传（基于文件名判断）
            checkResumeTransferForFile(file: file)
        }
        
        // 发送文件列表到 Flutter
        let fileList = files.map { file in
            [
                "sn": file.sn,
                "name": file.name,
                "size": file.size,
                "scene": file.scene,
                "startTimestamp": Int(file.startTimestamp),
                "endTimestamp": Int(file.endTimestamp)
            ]
        }
        NVEasyPlugin.methodChannel?.invokeMethod("didReceiveFiles", arguments: fileList)
        
        // 开始下载所有文件
        guard let bleManager = bleManager else {
            NVEasyLogger.error("❌ [文件列表] BLEManager引用丢失")
            return
        }
        
        // 开始下载所有文件
        BLELogger.log("📁 [文件传输] 开始下载所有文件，共 \(files.count) 个文件")
        
        // 实现下载文件的逻辑
        startFileDownload(files: files)
    }
    
    // MARK: - WiFi Hotspot Callbacks
    
    /// WiFi 热点开启回调
    /// - Parameters:
    ///   - manager: 文件管理器实例
    ///   - isOpen: 是否开启
    ///   - hwIP: 硬件IP地址
    ///   - hwPort: 硬件端口
    ///   - appIP: 应用IP地址
    ///   - appPort: 应用端口
    ///   - softAPSSID: WiFi热点名称
    ///   - softAPPassword: WiFi热点密码
    func handleWiFiHotspotOpen(manager: NVEasyFileManager, isOpen: Bool, hwIP: String, hwPort: String, appIP: String, appPort: String, softAPSSID: String, softAPPassword: String) {
        if isOpen {
            NVEasyLogger.success("📶 [WiFi热点] 开启成功")
            NVEasyLogger.info("  - 硬件IP: \(hwIP):\(hwPort)")
            NVEasyLogger.info("  - 应用IP: \(appIP):\(appPort)")
            NVEasyLogger.info("  - 热点名称: \(softAPSSID)")
            NVEasyLogger.info("  - 热点密码: \(softAPPassword)")
        } else {
            NVEasyLogger.error("❌ [WiFi热点] 开启失败")
        }
    }
    
    // MARK: - Private Methods
    
    /// 开始文件下载
    /// - Parameter files: 要下载的文件列表
    private func startFileDownload(files: [NVEasyFileInfo]) {
        // 检查蓝牙连接状态
        guard NVEasyBLEManager.shared.isConnected else {
            NVEasyLogger.error("❌ [文件下载] 蓝牙未连接，无法下载文件")
            return
        }
        
        // 检查文件列表是否为空
        guard !files.isEmpty else {
            NVEasyLogger.warning("⚠️ [文件下载] 文件列表为空，无需下载")
            return
        }
        
        NVEasyLogger.info("📁 [文件下载] 开始下载 \(files.count) 个文件")
        
        // 使用 FileTransferManager 进行串行下载
        FileTransferManager.shared.startDownloadAllFilesViaBluetooth(files: files)
        
        NVEasyLogger.info("📁 [文件下载] 已通知Flutter端开始下载")
    }
    
    /// 检查文件是否支持断点续传
    /// - Parameter file: 文件信息
    private func checkResumeTransferForFile(file: NVEasyFileInfo) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // 根据文件开始时间戳生成预期的MP3文件名
        let startTime = Int(file.startTimestamp)
        let expectedMP3FileName = "file_\(startTime).mp3"
        let expectedMP3Path = documentsPath.appendingPathComponent(expectedMP3FileName).path
        
        // 检查MP3文件是否已存在
        if FileManager.default.fileExists(atPath: expectedMP3Path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: expectedMP3Path)
                let fileSize = attributes[.size] as? Int ?? 0
                
                // 如果文件已存在且大小大于0，说明可能已经部分传输
                if fileSize > 0 {
                    NVEasyLogger.info("📁 [断点续传] 文件 \(file.sn) 发现已存在的MP3文件: \(expectedMP3Path), 大小: \(fileSize) bytes")
                    
                    // 初始化断点续传状态
                    ResumeTransferManager.shared.startTransfer(file: file)
                } else {
                    NVEasyLogger.info("📁 [断点续传] 文件 \(file.sn) MP3文件存在但为空，将重新传输")
                }
            } catch {
                NVEasyLogger.error("❌ [断点续传] 文件 \(file.sn) 检查已存在文件失败: \(error)")
            }
        } else {
            NVEasyLogger.info("📁 [断点续传] 文件 \(file.sn) 未发现已存在的MP3文件，将完整传输")
        }
    }
    
    /// 传输信息结构体
    private struct TransferInfo {
        let isResumeTransfer: Bool
        let actualPacketNumber: Int
        let displayTotalPackets: Int
    }
    
    /// 处理断点续传逻辑
    /// - Parameters:
    ///   - fileSN: 文件序列号
    ///   - pkgNum: 当前包号
    ///   - totalPkgCount: 总包数
    /// - Returns: 传输信息
    private func processResumeTransferLogic(fileSN: Int, pkgNum: Int, totalPkgCount: Int) -> TransferInfo {
        let isResumeTransfer = ResumeTransferManager.shared.canResumeTransfer(fileSN: fileSN)
        let transferState = ResumeTransferManager.shared.getTransferState(fileSN: fileSN) as? ResumeTransferManager.TransferState
        let previousPackets = transferState?.receivedPackets ?? 0
        
        // 计算实际包号
        let actualPacketNumber: Int
        if isResumeTransfer {
            // 断点续传：实际包号 = 已接收包数 + 当前包号
            actualPacketNumber = previousPackets + 1
        } else {
            // 正常传输：实际包号 = 当前包号
            actualPacketNumber = pkgNum
        }
        
        // 获取显示的总包数
        let displayTotalPackets = transferState?.totalPackets ?? totalPkgCount
        
        NVEasyLogger.debug("📁 [断点续传] 文件 \(fileSN) - 是否续传: \(isResumeTransfer), 实际包号: \(actualPacketNumber), 显示总包数: \(displayTotalPackets)")
        
        return TransferInfo(
            isResumeTransfer: isResumeTransfer,
            actualPacketNumber: actualPacketNumber,
            displayTotalPackets: displayTotalPackets
        )
    }
    
    /// 初始化文件传输
    /// - Parameters:
    ///   - bleManager: BLE管理器
    ///   - fileSN: 文件序列号
    ///   - totalPkgCount: 总包数
    private func initializeFileTransfer(bleManager: BLEManager, fileSN: Int, totalPkgCount: Int) {
        NVEasyLogger.info("📁 [文件传输] 初始化文件 \(fileSN) 传输，总包数: \(totalPkgCount)")
        
        // 设置传输开始时间
        FileTransferManager.setOpusStartTime(Date())
        
        // 初始化音频数据缓存
        bleManager.initFileAudioData(for: fileSN)
        
        // 更新断点续传管理器
        ResumeTransferManager.shared.updateTotalPackets(fileSN: fileSN, totalPackets: totalPkgCount)
    }
    
    /// 获取文件在当前下载列表中的索引（从1开始）
    /// - Parameter fileSN: 文件序列号
    /// - Returns: 文件索引，如果未找到返回1
    private func getFileIndex(fileSN: Int) -> Int {
        // 使用 FileTransferManager 的 pendingFiles 获取文件索引
        let pendingFiles = FileTransferManager.shared.pendingFiles
        
        // 查找当前文件的索引
        for (index, file) in pendingFiles.enumerated() {
            if file.sn == fileSN {
                return index + 1 // 从1开始计数
            }
        }
        
        // 如果未找到，返回1作为默认值
        NVEasyLogger.warning("⚠️ [文件索引] 未找到文件 \(fileSN) 的索引，使用默认值1")
        return 1
    }
    
    /// 更新传输进度
    /// - Parameters:
    ///   - fileSN: 文件序列号
    ///   - actualPacketNumber: 实际包号
    ///   - totalPackets: 总包数
    ///   - dataSize: 数据大小
    private func updateTransferProgress(fileSN: Int, actualPacketNumber: Int, totalPackets: Int, dataSize: Int) {
        // 更新断点续传进度
        ResumeTransferManager.shared.updateTransferProgress(
            fileSN: fileSN,
            receivedPackets: actualPacketNumber,
            totalPackets: totalPackets,
            receivedBytes: dataSize
        )
        
        // 获取当前文件在下载列表中的索引
        let currentNumber = getFileIndex(fileSN: fileSN)
        
        // 发送下载进度到UI
        sendDownloadFileProgress(
            currentPacket: actualPacketNumber,
            totalPacket: totalPackets,
            currentNumber: currentNumber
        )
        
        // 记录进度日志
        let progress = Double(actualPacketNumber) / Double(totalPackets) * 100
        NVEasyLogger.debug("📁 [传输进度] 文件 \(fileSN) 进度: \(String(format: "%.1f", progress))% (\(actualPacketNumber)/\(totalPackets)), 文件索引: \(currentNumber)")
    }
    
    /// 更新速度计算
    /// - Parameters:
    ///   - bleManager: BLE管理器
    ///   - fileSN: 文件序列号
    ///   - pkgNum: 包号
    ///   - dataSize: 数据大小
    private func updateSpeedCalculation(bleManager: BLEManager, fileSN: Int, pkgNum: Int, dataSize: Int) {
        if pkgNum == 1 {
            // 第一个包：重置速度计算
            bleManager.resetSpeedCalculation(for: fileSN)
        } else {
            // 后续包：更新速度计算
            bleManager.updateSpeedCalculation(for: fileSN, dataSize: dataSize)
            
            // 获取并发送下载速度
            if let speedInfo = bleManager.getSpeedCalculationInfo(for: fileSN) {
                sendFileDownloadSpeed(speedKbps: speedInfo.speedKbps)
            }
        }
    }
    
    /// 处理蓝牙传输成功
    private func handleBluetoothTransferSuccess(bleManager: BLEManager, fileSN: Int) {
        // 清理 OPUS 传输开始时间
        FileTransferManager.clearOpusStartTime()
        
        // 完成断点续传
        ResumeTransferManager.shared.completeTransfer(fileSN: fileSN, success: true, error: nil)
        
        // 刷新所有缓冲区数据到文件
        bleManager.flushAllBuffersToFile(fileSN: fileSN)
        
        // 完成实时MP3编码并获取文件路径
        if let mp3Path = fileMP3Paths[fileSN] {
            NVEasyLogger.info("📁 [蓝牙文件传输] 文件 \(fileSN) 使用实时生成的MP3文件: \(mp3Path)")
            
            // 完成MP3编码
            finalizeFileMP3Encoding(fileSN: fileSN)
            
            // 处理MP3转换完成
            handleMP3ConversionComplete(bleManager: bleManager, fileSN: fileSN, mp3Path: mp3Path)
        } else {
            NVEasyLogger.error("❌ [蓝牙文件传输] 文件 \(fileSN) 无法获取MP3文件路径")
            self.handleFileProcessingComplete(bleManager: bleManager, fileSN: fileSN, success: false)
        }
    }
    
    /// 处理蓝牙传输失败
    private func handleBluetoothTransferFailure(bleManager: BLEManager, fileSN: Int, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "未知错误"
        NVEasyLogger.error("❌ [蓝牙文件传输] 文件 \(fileSN) 传输失败: \(errorMessage)")
        
        // 记录断点续传失败状态
        ResumeTransferManager.shared.transferFailed(fileSN: fileSN, error: errorMessage)
        
        // 清理文件传输资源（即使失败也要清理）
        cleanupFileTransferResources(fileSN: fileSN)
        
        // 清理文件信息缓存，通过fileSN查找对应的文件名
        if let fileName = fileInfoCache.first(where: { $0.value.sn == fileSN })?.key {
            fileInfoCache[fileName] = nil
        }
        
        // 发送下载失败通知到Flutter端
        let arguments: [String: Any] = [
            "fileSN": fileSN,
            "success": false,
            "error": errorMessage
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("didReceiveFileDownloadError", arguments: arguments)
        
        // 通知串行下载管理器文件下载失败
        self.handleFileProcessingComplete(bleManager: bleManager, fileSN: fileSN, success: false)
    }
    
    /// 处理OPUS数据解码
    /// - Parameters:
    ///   - bleManager: BLE管理器
    ///   - opusData: OPUS数据
    ///   - fileSN: 文件序列号
    ///   - pkgNum: 包号
    ///   - actualPacketNumber: 实际包号
    ///   - displayTotalPackets: 显示的总包数
    private func processOPUSData(bleManager: BLEManager, opusData: Data, fileSN: Int, pkgNum: Int, actualPacketNumber: Int, displayTotalPackets: Int) {
        // 文件传输默认使用会议模式（立体声道）
        let channels = 2
        NVEasyLogger.debug("📁 [OPUS解码] 文件 \(fileSN) 使用会议模式，声道数: \(channels)")
        
        // 处理解码后的数据
        func handleDecodedData(_ decodedData: Data?) {
            guard let decodedData = decodedData else {
                NVEasyLogger.error("❌ [OPUS解码] 文件 \(fileSN) 解码失败")
                return
            }
            
            NVEasyLogger.debug("📁 [OPUS解码] 文件 \(fileSN) 解码成功 - PCM数据: \(decodedData.count) bytes")
            
            // 实时转换PCM数据为MP3并写入文件
            convertAndWriteMP3DataForFile(pcmData: decodedData, fileSN: fileSN, channels: channels)
            
            // 将解码后的PCM数据添加到音频缓存（用于兼容性）
            bleManager.appendFileAudioData(decodedData, for: fileSN)
        }
        
        // 选择解码器并处理数据
        let frameSize: Int32 = 80 // 文件传输通常使用80帧
        
        if frameSize == 80 {
            NVEasyLogger.debug("📁 [OPUS解码] 文件 \(fileSN) 使用80帧解码器")
            NVOpusCodec.enqueueAudio80Data(toDecode: opusData) { decodedData in
                handleDecodedData(decodedData)
            }
        } else {
            NVEasyLogger.debug("📁 [OPUS解码] 文件 \(fileSN) 使用40帧解码器")
            NVOpusCodec.enqueueAudio40Data(toDecode: opusData) { decodedData in
                handleDecodedData(decodedData)
            }
        }
    }
    
    /// 为文件实时转换PCM数据为MP3并写入文件
    /// - Parameters:
    ///   - pcmData: PCM数据
    ///   - fileSN: 文件序列号
    ///   - channels: 声道数
    private func convertAndWriteMP3DataForFile(pcmData: Data, fileSN: Int, channels: Int) {
        // 记录PCM数据信息，帮助调试LAME断言错误
        NVEasyLogger.debug("📊 [文件MP3] 文件 \(fileSN) PCM数据: \(pcmData.count) bytes, 声道数: \(channels)")
        
        // 验证PCM数据格式
        guard pcmData.count % 2 == 0 else {
            NVEasyLogger.error("❌ [文件MP3] 文件 \(fileSN) PCM数据长度不是偶数: \(pcmData.count)")
            return
        }
        
        let sampleCount = pcmData.count / 2
        NVEasyLogger.debug("📊 [文件MP3] 文件 \(fileSN) 样本数: \(sampleCount)")
        // 初始化音频转换器（如果尚未初始化）
        if fileAudioConverters[fileSN] == nil {
            do {
                let converter = try AudioConverter(sampleRate: 16000, channels: channels, bitrate: 128)
                fileAudioConverters[fileSN] = converter
                NVEasyLogger.info("🎵 [文件MP3] 文件 \(fileSN) 音频转换器已初始化 - 声道数: \(channels)")
            } catch {
                NVEasyLogger.error("❌ [文件MP3] 文件 \(fileSN) 音频转换器初始化失败: \(error)")
                return
            }
        }
        
        // 初始化MP3文件（如果尚未创建）
        if fileMP3Handles[fileSN] == nil {
            setupMP3FileForTransfer(fileSN: fileSN)
        }
        
        guard let converter = fileAudioConverters[fileSN] else {
            NVEasyLogger.error("❌ [文件MP3] 文件 \(fileSN) 音频转换器为空")
            return
        }
        
        // 实时转换PCM数据为MP3数据
        do {
            let mp3Data = try converter.convertPCMDataToMP3Data(pcmData: pcmData)
            
            // 将MP3数据写入文件
            if let mp3Handle = fileMP3Handles[fileSN] {
                mp3Handle.write(mp3Data)
                NVEasyLogger.debug("📝 [文件MP3] 文件 \(fileSN) 已写入MP3数据: \(mp3Data.count) bytes")
            }
            
        } catch {
            NVEasyLogger.error("❌ [文件MP3] 文件 \(fileSN) PCM转MP3失败: \(error)")
            
            // 如果是LAME断言错误或缓冲区错误，尝试重新初始化编码器
            if error.localizedDescription.contains("Assertion failed") || 
               error.localizedDescription.contains("SIGABRT") ||
               error.localizedDescription.contains("buffer") ||
               error.localizedDescription.contains("reservoir") {
                NVEasyLogger.warning("⚠️ [文件MP3] 检测到LAME缓冲区错误，尝试重新初始化编码器")
                fileAudioConverters[fileSN] = nil
                
                // 尝试重新初始化编码器
                do {
                    let newConverter = try AudioConverter(sampleRate: 16000, channels: channels, bitrate: 128)
                    fileAudioConverters[fileSN] = newConverter
                    NVEasyLogger.info("🔄 [文件MP3] 文件 \(fileSN) 编码器已重新初始化")
                } catch {
                    NVEasyLogger.error("❌ [文件MP3] 文件 \(fileSN) 编码器重新初始化失败: \(error)")
                }
                
                // 下次调用时会重新创建编码器
            }
        }
    }
    
    /// 为文件传输设置MP3文件
    /// - Parameter fileSN: 文件序列号
    private func setupMP3FileForTransfer(fileSN: Int) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // 使用缓存的文件信息，通过fileSN查找对应的文件信息
        guard let fileInfo = fileInfoCache.values.first(where: { $0.sn == fileSN }) else {
            NVEasyLogger.error("❌ [文件MP3] 文件 \(fileSN) 未找到缓存的文件信息")
            return
        }
        
        let startTime = Int(fileInfo.startTimestamp)
        let mp3FileName = "file_\(startTime).mp3"
        let mp3Path = documentsPath.appendingPathComponent(mp3FileName).path
        
        // 检查是否支持断点续传
        let isResumeTransfer = ResumeTransferManager.shared.canResumeTransfer(fileSN: fileSN)
        
        do {
            if isResumeTransfer && FileManager.default.fileExists(atPath: mp3Path) {
                // 断点续传：打开已存在的文件进行追加写入
                let mp3Handle = try FileHandle(forWritingTo: URL(fileURLWithPath: mp3Path))
                mp3Handle.seekToEndOfFile()
                
                // 缓存文件句柄和路径
                fileMP3Handles[fileSN] = mp3Handle
                fileMP3Paths[fileSN] = mp3Path
                
                NVEasyLogger.info("📁 [文件MP3] 文件 \(fileSN) 断点续传，打开已存在文件: \(mp3Path)")
            } else {
                // 新文件传输：创建新的MP3文件
                FileManager.default.createFile(atPath: mp3Path, contents: nil, attributes: nil)
                let mp3Handle = try FileHandle(forWritingTo: URL(fileURLWithPath: mp3Path))
                
                // 缓存文件句柄和路径
                fileMP3Handles[fileSN] = mp3Handle
                fileMP3Paths[fileSN] = mp3Path
                
                NVEasyLogger.info("📁 [文件MP3] 文件 \(fileSN) 新文件传输，创建MP3文件: \(mp3Path)")
            }
            
        } catch {
            NVEasyLogger.error("❌ [文件MP3] 文件 \(fileSN) 设置MP3文件失败: \(error)")
        }
    }
    
    /// 完成文件MP3编码（刷新编码器缓冲区）
    /// - Parameter fileSN: 文件序列号
    private func finalizeFileMP3Encoding(fileSN: Int) {
        guard let converter = fileAudioConverters[fileSN] else {
            NVEasyLogger.info("🎵 [文件MP3] 文件 \(fileSN) 音频转换器为空，无需刷新")
            return
        }
        
        // 刷新MP3编码器缓冲区，确保所有数据都被写入
        do {
            let flushData = try converter.flushEncoder()
            if let mp3Handle = fileMP3Handles[fileSN], !flushData.isEmpty {
                mp3Handle.write(flushData)
                NVEasyLogger.info("🎵 [文件MP3] 文件 \(fileSN) 编码器缓冲区已刷新: \(flushData.count) bytes")
            }
        } catch {
            NVEasyLogger.error("❌ [文件MP3] 文件 \(fileSN) 刷新编码器缓冲区失败: \(error)")
        }
        
        // 验证MP3文件
        if let mp3Path = fileMP3Paths[fileSN] {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: mp3Path)
                let fileSize = attributes[.size] as? Int ?? 0
                NVEasyLogger.info("📊 [文件MP3] 文件 \(fileSN) 最终MP3文件大小: \(fileSize) bytes")
            } catch {
                NVEasyLogger.error("❌ [文件MP3] 文件 \(fileSN) 检查MP3文件失败: \(error)")
            }
        }
    }
    
    /// 清理文件传输资源
    /// - Parameter fileSN: 文件序列号
    private func cleanupFileTransferResources(fileSN: Int) {
        // 完成MP3编码
        finalizeFileMP3Encoding(fileSN: fileSN)
        
        // 关闭MP3文件句柄
        if let mp3Handle = fileMP3Handles[fileSN] {
            mp3Handle.closeFile()
            fileMP3Handles[fileSN] = nil
            NVEasyLogger.info("📁 [文件MP3] 文件 \(fileSN) MP3文件句柄已关闭")
        }
        
        // 清理音频转换器
        fileAudioConverters[fileSN] = nil
        
        NVEasyLogger.info("🎵 [文件MP3] 文件 \(fileSN) 音频转换器已清理")
    }
    
    /// 处理MP3转换完成
    private func handleMP3ConversionComplete(bleManager: BLEManager, fileSN: Int, mp3Path: String) {
        // 从缓存中获取完整的文件信息，通过fileSN查找对应的文件信息
        guard let fileInfo = fileInfoCache.values.first(where: { $0.sn == fileSN }) else {
            NVEasyLogger.error("❌ [蓝牙文件传输] 文件 \(fileSN) 未找到缓存的文件信息")
            self.handleFileProcessingComplete(bleManager: bleManager, fileSN: fileSN, success: false)
            return
        }
        
        let scene = fileInfo.scene
        let startTimestamp = Int(fileInfo.startTimestamp)
        let endTimestamp = Int(fileInfo.endTimestamp)
        let fileDuration = endTimestamp - startTimestamp
        
        NVEasyLogger.info("📁 [蓝牙文件传输] 文件 \(fileSN) 使用缓存的文件信息 - 场景: \(scene), 开始: \(startTimestamp), 结束: \(endTimestamp), 时长: \(fileDuration)秒")
        
        // 发送MP3文件路径、时长和时间戳到Flutter端
        let arguments: [String: Any] = [
            "fileMp3Path": mp3Path,
            "fileDuration": fileDuration,
            "scene": scene,
            "recordStartTime": bleManager.formatDateToString(Date(timeIntervalSince1970: Double(startTimestamp))),
        ]
        NVEasyLogger.info("📁 [蓝牙文件传输] didReceiveRecordMP3FilePath: \(arguments)")
        NVEasyPlugin.methodChannel?.invokeMethod("didReceiveRecordMP3FilePath", arguments: arguments)
        
        // 清理音频数据
        bleManager.clearFileAudioData(for: fileSN)
        
        // 清理文件传输资源
        cleanupFileTransferResources(fileSN: fileSN)
        
        // 清理文件信息缓存，通过fileSN查找对应的文件名
        if let fileName = fileInfoCache.first(where: { $0.value.sn == fileSN })?.key {
            fileInfoCache[fileName] = nil
        }
        
        // 删除设备上的文件（使用实际的文件名）
        NVEasyBLEManager.shared.delfile(sn: fileSN, name: fileInfo.name)
        NVEasyLogger.info("🗑️ [文件删除] 已请求删除文件 SN: \(fileSN), 名称: \(fileInfo.name)")
        
        // 通知文件处理完成
        self.handleFileProcessingComplete(bleManager: bleManager, fileSN: fileSN, success: true)
    }
    
    /// 处理文件处理完成
    private func handleFileProcessingComplete(bleManager: BLEManager, fileSN: Int, success: Bool) {
        // 文件处理完成，记录日志
        NVEasyLogger.info("📁 [文件处理] 文件 \(fileSN) 处理完成，成功: \(success)")
        
        // 通知 FileTransferManager 文件下载完成
        FileTransferManager.shared.onFileDownloadComplete(success: success, fileSN: fileSN)
        
        // 检查是否所有文件都已处理完成
        checkAllFilesDownloadComplete()
    }
    
    /// 检查所有文件是否下载完成
    private func checkAllFilesDownloadComplete() {
        // 检查 FileTransferManager 的下载状态
        let downloadProgress = FileTransferManager.shared.getDownloadProgress()
        
        if !downloadProgress.isDownloading {
            // 所有文件下载完成
            NVEasyLogger.success("✅ [文件下载] 所有文件下载完成")
            
            NVEasyLogger.info("📁 [文件下载] 已通知Flutter端下载完成")
        }
    }
    
    
    /// 格式化日期时间字符串
    private func formatDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    // MARK: - Flutter Plugin Methods (对齐Android端)
    
    /// 发送文件下载进度更新
    /// - Parameters:
    ///   - currentPacket: 当前包号
    ///   - totalPacket: 总包数
    ///   - currentNumber: 当前文件编号
    private func sendDownloadFileProgress(currentPacket: Int, totalPacket: Int, currentNumber: Int) {
        let progress = [
            "currentPacket": currentPacket,
            "totalPacket": totalPacket,
            "currentNumber": currentNumber
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("didUpdateDownloadFileProgress", arguments: progress)
        NVEasyLogger.debug("📁 [下载进度] 发送进度更新: \(currentPacket)/\(totalPacket), 文件编号: \(currentNumber)")
    }
    
    /// 发送文件下载速度
    /// - Parameter speedKbps: 下载速度 (KB/s)
    private func sendFileDownloadSpeed(speedKbps: Int) {
        let speedData = [
            "speedKbps": speedKbps
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("fileDownloadSpeed", arguments: speedData)
        NVEasyLogger.debug("📁 [下载速度] 发送速度更新: \(speedKbps) KB/s")
    }
    
//    /// 发送下载所有文件UI状态
//    /// - Parameter downFileStatus: 下载状态
//    ///   - 0: 开始下载
//    ///   - 1: 下载中
//    ///   - 2: 下载完成
//    ///   - 3: 下载失败
//    private func sendDownloadAllFileUI(downFileStatus: Int) {
//        let statusData = [
//            "downFileStatus": downFileStatus
//        ]
//        NVEasyPlugin.methodChannel?.invokeMethod("sendDownloadAllFileUI", arguments: statusData)
//        
//        let statusText = getDownloadStatusText(downFileStatus)
//        NVEasyLogger.info("📁 [下载状态] 发送状态更新: \(statusText) (状态码: \(downFileStatus))")
//    }
    
    /// 获取下载状态文本描述
    /// - Parameter status: 状态码
    /// - Returns: 状态文本
    private func getDownloadStatusText(_ status: Int) -> String {
        switch status {
        case 0:
            return "开始下载"
        case 1:
            return "下载中"
        case 2:
            return "下载完成"
        case 3:
            return "下载失败"
        default:
            return "未知状态"
        }
    }
}

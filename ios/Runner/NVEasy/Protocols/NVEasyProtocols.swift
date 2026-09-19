import Foundation
import CoreBluetooth
import NVEasySDK

// MARK: - BLE Manager Protocol

/// BLE管理器协议
/// 定义BLE连接和操作的标准接口
public protocol BLEManagerProtocol: NVEasyHardwareDelegate {
    // MARK: - 扫描操作
    func startScan()
    func stopScan()
    
    // MARK: - 连接操作
    func connect(_ uuid: String)
    func disconnect(_ uuid: String)
    
    // MARK: - 设备操作
    func resetDevice()
    func queryVersion()
    func querySN()
    func setName(_ name: String)
    func getBattery()
    func setOffTime(minutes: Int)
    func getBindStatus() -> Bool
    func bindDevice(isBind: Bool)
    
    // MARK: - 多设备支持
    func connectExA(_ uuid: String)
    func connectExB(_ uuid: String)
    func disconnectExA(_ uuid: String)
    func disconnectExB(_ uuid: String)
}

// MARK: - File Manager Protocol

/// 文件管理器协议
/// 定义文件操作的标准接口
public protocol FileManagerProtocol {
    // MARK: - 文件列表操作
    func getFileList()
    
    // MARK: - 文件下载操作
    func downloadFile(sn: Int, useWifi: Bool)
    func downloadFile(sn: Int, offsetInBytes: Int, useWifi: Bool)
//    func downloadFileByWifi(sn: Int)
    
    // MARK: - WiFi操作
    func closeWiFi()
    
    // MARK: - 批量下载操作
    func downloadAllFilesViaBluetooth(files: [NVEasyFileInfo])
    func stopSerialDownload()
}

// MARK: - Audio Manager Protocol

/// 音频管理器协议
/// 定义音频处理的标准接口
public protocol AudioManagerProtocol {
    // MARK: - 录音操作
    func initOpus(mono: Bool)
    func startRecord()
    func pauseRecord()
    func resumeRecord()
    func stopRecord() -> [String: String]?
    
    // MARK: - 音频模式设置
    var isHuiYi: Bool { get set }
    var isMono: Bool { get set }
}

// MARK: - Audio Data Manager Protocol

/// 音频数据管理器协议
/// 定义音频数据存储和处理的标准接口
public protocol AudioDataManagerProtocol {
    // MARK: - 文件音频数据管理
    func initFileAudioData(for fileSN: Int)
    func appendFileAudioData(_ data: Data, for fileSN: Int)
    func getFileAudioData(for fileSN: Int) -> Data?
    func clearFileAudioData(for fileSN: Int)
    func clearAllFileAudioData()
    
    // MARK: - 实时音频流式处理
    func appendRealtimeAudioData(_ data: Data)
    func getRealtimeAudioData() -> Data?
    func cleanupRealtimeAudioStream()
    
    // MARK: - 缓冲区管理
    func flushAllBuffersToFile(fileSN: Int)
    
    // MARK: - 属性访问
    var audioData: Data? { get set }
    var lastAudioData: Data? { get set }
    var lastCardMode: Int { get set }
}

// MARK: - File Transfer Manager Protocol

/// 文件传输管理器协议
/// 定义文件传输管理的标准接口
public protocol FileTransferManagerProtocol {
    // MARK: - 传输状态管理
    static func isFileProcessed(fileSN: Int) -> Bool
    static func markFileAsProcessed(fileSN: Int)
    static func isWifiFileProcessed(fileSN: Int) -> Bool
    static func markWifiFileAsProcessed(fileSN: Int)
    
    // MARK: - 当前传输管理
    static func setCurrentTransferFileSN(_ fileSN: Int?)
    static func getCurrentTransferFileSN() -> Int?
    static func setCurrentWifiTransferFileSN(_ fileSN: Int?)
    static func getCurrentWifiTransferFileSN() -> Int?
    
    // MARK: - OPUS传输时间管理
    static func setOpusStartTime(_ time: Date?)
    static func getOpusStartTime() -> Date?
    static func clearOpusStartTime()
    static func clearAllFileTransferStates()
    
    // MARK: - 串行下载管理
    func clearSerialDownloadState()
    func isCurrentlyDownloading() -> Bool
    func stopSerialDownload()
    func getDownloadProgress() -> (current: Int, total: Int, isDownloading: Bool)
    
    // MARK: - 下载操作
    func startDownloadAllFilesViaBluetooth(files: [NVEasyFileInfo])
    func onFileDownloadComplete(success: Bool, fileSN: Int)
}

// MARK: - Resume Transfer Manager Protocol

/// 断点续传管理器协议
/// 定义断点续传管理的标准接口
public protocol ResumeTransferManagerProtocol {
    // MARK: - 传输状态管理
    func startTransfer(file: NVEasyFileInfo)
    func updateTransferProgress(fileSN: Int, receivedPackets: Int, totalPackets: Int, receivedBytes: Int)
    func completeTransfer(fileSN: Int, success: Bool, error: Error?)
    func getTransferState(fileSN: Int) -> Any?
    func clearTransferState(fileSN: Int)
    func clearAllTransferStates()
    
    // MARK: - 批量操作
    func clearCompletedTransfers()
    func getResumableTransfers() -> [Any]
    
    // MARK: - 状态检查
    func hasTransferState(fileSN: Int) -> Bool
    func isTransferCompleted(fileSN: Int) -> Bool
}

// MARK: - Error Manager Protocol

/// 错误管理器协议
/// 定义错误处理的标准接口
public protocol ErrorManagerProtocol {
    // MARK: - 错误处理
    func handleError(_ error: Error, context: String, result: @escaping FlutterResult)
    func handleParameterError(missingParameter: String, result: @escaping FlutterResult)
    func handleConnectionError(deviceId: String, result: @escaping FlutterResult)
    func handleDeviceNotFoundError(deviceId: String, result: @escaping FlutterResult)
}

// MARK: - Resource Cleanup Manager Protocol

/// 资源清理管理器协议
/// 定义资源清理的标准接口
public protocol ResourceCleanupManagerProtocol {
    // MARK: - 清理任务管理
    func registerCleanupTask(_ task: @escaping () -> Void)
    func performCleanup()
    func cleanupResource(type: String)
}

// MARK: - Command Queue Manager Protocol

/// 指令队列管理器协议
/// 定义指令队列管理的标准接口
public protocol CommandQueueManagerProtocol {
    // MARK: - 指令防抖
    func shouldDebounceCommand(type: String) -> Bool
    func updateLastExecutionTime(type: String)
    func clearExecutionTimes()
}

// MARK: - Method Handler Protocol

/// 方法处理器协议
/// 定义所有方法处理器必须实现的标准接口
public protocol MethodHandlerProtocol {
    /// 处理方法调用
    /// - Parameters:
    ///   - method: 方法名
    ///   - arguments: 参数
    ///   - result: 结果回调
    /// - Returns: 是否处理了该方法
    func handle(method: String, arguments: [String: Any]?, result: @escaping FlutterResult) -> Bool
}

/// 基础方法处理器
/// 提供方法处理器的默认实现，子类可以继承并重写特定方法
public class BaseMethodHandler: MethodHandlerProtocol {
    
    /// 默认处理方法调用
    /// - Parameters:
    ///   - method: 方法名
    ///   - arguments: 参数
    ///   - result: 结果回调
    /// - Returns: 默认返回false，表示未处理
    public func handle(method: String, arguments: [String: Any]?, result: @escaping FlutterResult) -> Bool {
        return false
    }
}

// MARK: - Method Handler Manager Protocol

/// 方法处理器管理器协议
/// 定义方法处理器管理的标准接口
public protocol MethodHandlerManagerProtocol {
    // MARK: - 方法处理
    func handle(method: String, arguments: [String: Any]?, result: @escaping FlutterResult) -> Bool
    func getHandlerCount() -> Int
}

// MARK: - Speed Calculation Manager Protocol

/// 速度计算管理器协议
public protocol SpeedCalculationManagerProtocol {
    func resetSpeedCalculation(for fileSN: Int)
    func updateSpeedCalculation(for fileSN: Int, dataSize: Int)
    func clearSpeedCalculation(for fileSN: Int)
    func clearAllSpeedCalculations()
    func getSpeedCalculationInfo(for fileSN: Int) -> (totalBytes: Int, elapsedTime: TimeInterval, speedKbps: Int)?
    func getAllCalculatingFiles() -> [Int]
}

// MARK: - Realtime Audio Stream Manager Protocol

/// 实时音频流管理器协议
public protocol RealtimeAudioStreamManagerProtocol {
    func initRealtimeAudioStream()
    func appendRealtimeAudioData(_ data: Data)
    func checkRealtimeMemoryPressure(_ audioData: Data) -> Data
    func getRealtimeAudioData() -> Data?
    func cleanupRealtimeAudioStream()
    func getRealtimeAudioFilePath() -> String?
    func isInitialized() -> Bool
}

// MARK: - Recording Time Manager Protocol

/// 录音时间管理器协议
public protocol RecordingTimeManagerProtocol {
    func setRecordStartTime()
    func getRecordStartTime() -> Date?
    func clearRecordStartTime()
    func getRecordDuration() -> TimeInterval
    func isRecording() -> Bool
    func formatDateToString(_ date: Date) -> String
    func formatCurrentDateToString() -> String
    func formatRecordStartTimeToString() -> String
    func formatRecordDurationToString() -> String
    func getRecordingStatusInfo() -> [String: Any]
    func resetRecordingTime()
}

// MARK: - File Transfer Delegate Manager Protocol

/// 文件传输委托管理器协议
public protocol FileTransferDelegateManagerProtocol {
    func setBLEManager(_ bleManager: BLEManager)
    func handleBluetoothFileTransferFinish(manager: NVEasyFileManager, isFinish: Bool, fileSN: Int, error: Error?)
    func handleBluetoothFileTransferData(manager: NVEasyFileManager, opusData: Data, fileSN: Int, totalPkgCount: Int, pkgNum: Int)
    func handleWiFiFileTransferFinish(manager: NVEasyFileManager, isFinish: Bool, fileSN: Int, error: Error?)
    func handleWiFiFileTransferData(manager: NVEasyFileManager, opusData: Data, fileSN: Int, totalPkgCount: Int, pkgNum: Int)
    func handleFileListReceived(manager: NVEasyFileManager, files: [NVEasyFileInfo])
    func handleWiFiHotspotOpen(manager: NVEasyFileManager, isOpen: Bool, hwIP: String, hwPort: String, appIP: String, appPort: String, softAPSSID: String, softAPPassword: String)
}

// MARK: - Audio Processing Delegate Manager Protocol

/// 音频处理委托管理器协议
public protocol AudioProcessingDelegateManagerProtocol {
    func setBLEManager(_ bleManager: BLEManager)
    func handleRealTimeOPUSData(manager: NVEasyBLEManager, opusData: Data, framSize: Int32)
    func handleRecordingStatusUpdate(manager: NVEasyBLEManager, action: NVEasyRecordAction, mode: NVEasyRecordMode, sampleRate: NVEasyRecordSampleRate, channels: Int, recordType: NVEasyRecordType, msDuration: UInt)
}

// MARK: - OTA Delegate Manager Protocol

/// OTA升级委托管理器协议
public protocol OTADelegateManagerProtocol {
    func handleOTAStart(otaManager: NVEasyOTAManager)
    func handleOTAEnd(otaManager: NVEasyOTAManager)
    func handleOTAProgress(otaManager: NVEasyOTAManager, progress: Double, error: Error?)
    func getOTAStatusInfo() -> [String: Any]
    func resetOTAStatus()
}

// MARK: - Device Status Delegate Manager Protocol

/// 设备状态委托管理器协议
public protocol DeviceStatusDelegateManagerProtocol {
    func handleCallStateUpdate(manager: NVEasyBLEManager, state: NVEasyCallState, callNumber: String?)
    func handleVersionInfo(manager: NVEasyBLEManager, software: String, hardware: String)
    func handleBatteryUpdate(manager: NVEasyBLEManager, left: UInt, right: UInt, caseBattery: UInt)
    func handleVolumeUpdate(manager: NVEasyBLEManager, volume: UInt)
    func handlePlayStateUpdate(manager: NVEasyBLEManager, state: NVEasyPlayState)
    func handleAncUpdate(manager: NVEasyBLEManager, anc: NVEasyANCOption)
    func handleEqUpdate(manager: NVEasyBLEManager, eq: NVEasyEQOption)
    func handleBoundStatusUpdate(manager: NVEasyBLEManager, isSuccess: Bool, isBound: Bool)
    func handleMemoryUpdate(manager: NVEasyBLEManager, emptySizeOfKB: Int, totalSizeOfKB: Int, isFormatSuccess: Bool?)
    func handleStateUpdate(manager: NVEasyBLEManager, state: NVEasyBLEManager.State, isConnected: Bool)
    func handleAuthsn(manager: NVEasyBLEManager, sn: String, bleMac: String, wifiMac: String)
    func handleAlgorithmKey(manager: NVEasyBLEManager, key: Data)
    func handleError(manager: NVEasyBLEManager, error: Error)
    func getDeviceStatusInfo() -> [String: Any]
    func resetDeviceStatus()
} 

import Foundation
import NVEasySDK

/// 设备状态委托管理器
/// 负责处理所有设备状态相关的回调事件
class DeviceStatusDelegateManager: DeviceStatusDelegateManagerProtocol {
    
    // MARK: - Singleton
    static let shared = DeviceStatusDelegateManager()
    
    // MARK: - Properties
    
    var recordMode: NVEasyRecordMode?;
    
    public var isMeeting: Bool {
        return recordMode == .meeting
    }
    
    /// 访问锁
    private let statusLock = NSLock()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Device Status Callbacks
    
    /// 通话状态更新回调
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - state: 通话状态
    ///   - callNumber: 电话号码
    func handleCallStateUpdate(manager: NVEasyBLEManager, state: NVEasyCallState, callNumber: String?) {
        NVEasyLogger.info("📞 [通话状态] 状态: \(state), 号码: \(callNumber ?? "无")")
    }
    
    /// 接收到软件和硬件版本信息
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - software: 软件版本
    ///   - hardware: 硬件版本
    func handleVersionInfo(manager: NVEasyBLEManager, software: String, hardware: String) {
        NVEasyLogger.info("📋 [版本信息] 软件版本: \(software), 硬件版本: \(hardware)")
        let arguments: [String: Any] = ["softwareVersion": software]
        NVEasyPlugin.methodChannel?.invokeMethod("deviceVersion", arguments: arguments)
    }
    
    /// 电池电量更新回调
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - left: 左耳电量
    ///   - right: 右耳电量
    ///   - caseBattery: 充电盒电量
    func handleBatteryUpdate(manager: NVEasyBLEManager, left: UInt, right: UInt, caseBattery: UInt) {
        NVEasyLogger.info("🔋 [电池电量] 左耳: \(left)%, 右耳: \(right)%, 充电盒: \(caseBattery)%")
        let arguments: [String: Any] = ["left": left, "right": right, "caseBattery": caseBattery]
        NVEasyPlugin.methodChannel?.invokeMethod("didUpdateBattery", arguments: arguments)
    }
    
    /// 音量更新回调
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - volume: 音量值
    func handleVolumeUpdate(manager: NVEasyBLEManager, volume: UInt) {
        NVEasyLogger.info("🔊 [音量] 音量值: \(volume)")
    }
    
    /// 播放状态更新回调
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - state: 播放状态
    func handlePlayStateUpdate(manager: NVEasyBLEManager, state: NVEasyPlayState) {
        NVEasyLogger.info("▶️ [播放状态] 状态: \(state)")
    }
    
    /// ANC 降噪状态更新回调
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - anc: ANC 选项
    func handleAncUpdate(manager: NVEasyBLEManager, anc: NVEasyANCOption) {
        NVEasyLogger.info("🎧 [ANC降噪] 选项: \(anc)")
    }
    
    /// EQ 均衡器状态更新回调
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - eq: EQ 选项
    func handleEqUpdate(manager: NVEasyBLEManager, eq: NVEasyEQOption) {
        NVEasyLogger.info("🎛️ [EQ均衡器] 选项: \(eq)")
    }
    
    /// 绑定状态更新回调
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - isSuccess: 是否成功
    ///   - isBound: 是否已绑定
    func handleBoundStatusUpdate(manager: NVEasyBLEManager, isSuccess: Bool, isBound: Bool) {
        NVEasyLogger.info("🔗 [绑定状态] 成功: \(isSuccess), 已绑定: \(isBound)")
    }
    
    /// 内存状态更新回调
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - emptySizeOfKB: 空闲大小（KB）
    ///   - totalSizeOfKB: 总大小（KB）
    ///   - isFormatSuccess: 格式化是否成功
    func handleMemoryUpdate(manager: NVEasyBLEManager, emptySizeOfKB: Int, totalSizeOfKB: Int, isFormatSuccess: Bool?) {
        NVEasyLogger.info("💾 [内存状态] 空闲: \(emptySizeOfKB)KB, 总计: \(totalSizeOfKB)KB, 格式化成功: \(isFormatSuccess ?? false)")
    }
    
    /// 设备状态更新回调
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - state: 设备状态
    ///   - isConnected: 是否已连接
    func handleStateUpdate(manager: NVEasyBLEManager, state: NVEasyBLEManager.State, isConnected: Bool) {
        NVEasyLogger.info("📱 [设备状态] 状态: \(state), 已连接: \(isConnected)")
        
        // 当设备断电且未连接时，需要结束正常录制的音频文件
        if state == .poweredOff && !isConnected {
            NVEasyLogger.warning("⚠️ [设备状态] 设备断电且未连接，检查并结束录音")
            
            // 调用 didDisconnect 的逻辑
            handleDeviceDisconnection()
        
            // 停止下载
            stopAllDownloads()
            
            // 发送 didDisconnect 事件到 Flutter 端
            let disconnectArguments: [String: Any?] = [
                "uuid": BLEManager.shared.firstPeripheral?.mac,
                "name": BLEManager.shared.firstPeripheral?.name
            ]
            NVEasyPlugin.methodChannel?.invokeMethod("didDisconnect", arguments: disconnectArguments)
        }
    }
    
    /// 处理设备断开连接时的录音清理
    private func handleDeviceDisconnection() {
        // 发送录音状态更新到Flutter端
        let arguments: [String: Any] = [
            "status": 0,  // 0表示录音停止
            "mode": recordMode == .meeting ? 0 : 1,  // 0表示会议模式，1表示通话模式
            "reason": "device_disconnected"  // 断开原因
        ]
        
        // 检查是否正在录音
        guard BLEManager.shared.isRecording() else {
            NVEasyLogger.info("📱 [设备断开] 当前未在录音，无需处理")
            return
        }

        NVEasyLogger.warning("⚠️ [设备断开] 检测到录音中断，开始清理录音资源")
        
        // 获取录音开始时间用于日志记录
        if let recordStartTime = BLEManager.shared.getRecordStartTime() {
            let duration = BLEManager.shared.getRecordDuration()
            NVEasyLogger.info("📱 [设备断开] 录音开始时间: \(BLEManager.shared.formatDateToString(recordStartTime))")
            NVEasyLogger.info("📱 [设备断开] 录音持续时间: \(String(format: "%.1f", duration))秒")
        }
        
        // 判断录音模式
        let isMeeting = recordMode == .meeting
        
        // 调用 AudioProcessingDelegateManager 的录音停止处理方法
        // 这会正确处理录音文件并发送 didReceiveRecordMP3FilePath 事件
        AudioProcessingDelegateManager.shared.handleDeviceDisconnectionRecordStop(isMeeting: isMeeting)
        
        NVEasyLogger.info("📱 [设备断开] 录音资源清理完成，已通知Flutter端")
    }
    
    /// 接收到认证序列号
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - sn: 序列号
    ///   - bleMac: BLE MAC地址
    ///   - wifiMac: WiFi MAC地址
    func handleAuthsn(manager: NVEasyBLEManager, sn: String, bleMac: String, wifiMac: String) {
        NVEasyLogger.info("🔐 [认证信息] SN: \(sn), BLE MAC: \(bleMac), WiFi MAC: \(wifiMac)")
    }
    
    /// 接收到算法密钥
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - key: 算法密钥
    func handleAlgorithmKey(manager: NVEasyBLEManager, key: Data) {
        NVEasyLogger.info("🔑 [算法密钥] 密钥长度: \(key.count) 字节")
    }
    
    /// 错误处理回调
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - error: 错误信息
    func handleError(manager: NVEasyBLEManager, error: Error) {
        NVEasyLogger.error("❌ [设备错误] 错误: \(error.localizedDescription)")
    }
    
    // MARK: - Public Methods
    
    /// 获取设备状态信息
    /// - Returns: 设备状态信息字典
    func getDeviceStatusInfo() -> [String: Any] {
        return [
            "isConnected": false, // 需要根据实际状态更新
            "batteryLevel": 0,
            "volume": 0,
            "playState": "",
            "ancState": "",
            "eqState": "",
            "isBound": false
        ]
    }
    
    /// 重置设备状态
    func resetDeviceStatus() {
        NVEasyLogger.info("📱 [设备状态] 重置设备状态")
    }
    
    /// 停止所有下载任务
    private func stopAllDownloads() {
        NVEasyLogger.info("🛑 [设备断开] 开始停止所有下载任务")
        
        do {
            // 1. 停止文件传输委托管理器的下载
            NVEasyLogger.info("🛑 [设备断开] 停止文件传输委托管理器下载")
            FileTransferDelegateManager.shared.stopFileDownload()
            
            // 2. 停止文件传输管理器的串行下载
            NVEasyLogger.info("🛑 [设备断开] 停止文件传输管理器串行下载")
            FileTransferManager.shared.stopSerialDownload()
            
            // 3. 清理所有文件传输状态
            NVEasyLogger.info("🛑 [设备断开] 清理所有文件传输状态")
            FileTransferManager.clearAllFileTransferStates()
            
            // 4. 清理音频数据管理器的文件音频数据
            NVEasyLogger.info("🛑 [设备断开] 清理音频数据管理器文件音频数据")
            AudioDataManager.shared.clearAllFileAudioData()
            
            // 5. 清理速度计算数据
            NVEasyLogger.info("🛑 [设备断开] 清理速度计算数据")
            BLEManager.shared.clearAllSpeedCalculations()
            
            // 6. 发送下载停止事件到Flutter端
            let stopDownloadArguments: [String: Any] = [
                "reason": "device_disconnected",
                "timestamp": Date().timeIntervalSince1970
            ]
            NVEasyPlugin.methodChannel?.invokeMethod("downloadStopped", arguments: stopDownloadArguments)
            
            NVEasyLogger.info("✅ [设备断开] 所有下载任务已停止，资源已清理")
            
        } catch {
            NVEasyLogger.error("❌ [设备断开] 停止下载任务时发生错误: \(error.localizedDescription)")
        }
    }
}

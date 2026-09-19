import Foundation
import CoreBluetooth
import NVEasySDK
import Flutter
import opus
import AVFoundation

/// BLEManager 的硬件代理扩展，处理所有 NVEasySDK 的回调事件
extension BLEManager: NVEasyHardwareDelegate {
    
    
    // MARK: - Connection Handlers
    
    public func ble(manager: NVEasySDK.NVEasyBLEManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        connectionHandler.handleConnectionFailure(manager: manager, peripheral: peripheral, error: error)
    }
    
    public func ble(manager: NVEasySDK.NVEasyBLEManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        connectionHandler.handleDisconnection(manager: manager, peripheral: peripheral, error: error)
    }
    
    public func ble(manager: NVEasySDK.NVEasyBLEManager, peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber) {
        connectionHandler.handleRSSIRead(manager: manager, peripheral: peripheral, rssi: RSSI)
    }
    
    public func ble(manager: NVEasyBLEManager, didConnect peripheral: CBPeripheral) {
        connectionHandler.handleConnectionSuccess(manager: manager, peripheral: peripheral)
    }
    
    public func ble(manager: NVEasyBLEManager, shouldDiscover peripheral: CBPeripheral, advertisementData: [String : Any]) -> Bool {
        return connectionHandler.shouldDiscoverDevice(manager: manager, peripheral: peripheral, advertisementData: advertisementData)
    }
    
    public func ble(manager: NVEasyBLEManager, didDiscover peripheral: CBPeripheral) {
        connectionHandler.handleDeviceDiscovery(manager: manager, peripheral: peripheral)
    }
    
    // MARK: - Command Handlers
    
    public func ble(manager: NVEasySDK.NVEasyBLEManager, didUpdateRecord action: NVEasySDK.NVEasyRecordAction, mode: NVEasySDK.NVEasyRecordMode, sampleRate: NVEasySDK.NVEasyRecordSampleRate, channels: Int, recordType: NVEasySDK.NVEasyRecordType, msDuration: UInt) {
        audioProcessingDelegateManager.handleRecordingStatusUpdate(manager: manager, action: action, mode: mode, sampleRate: sampleRate, channels: channels, recordType: recordType, msDuration: msDuration)
    }
    
    public func ble(manager: NVEasySDK.NVEasyBLEManager, didReceiveAuthsn sn: String, bleMac: String, wifiMac: String, labelSN: String?) {
        commandHandler.handleAuthsn(manager: manager, sn: sn, bleMac: bleMac, wifiMac: wifiMac, labelSN: labelSN)
    }
    
    public func ble(manager: NVEasySDK.NVEasyBLEManager, didReceivePairRole role: NVEasySDK.NVEasyPairRole, sn: String, labelSN: String, wifiMac: String?, leftMAC: String, rightMAC: String, caseMAC: String) {
        commandHandler.handlePairRole(manager: manager, role: role, sn: sn, labelSN: labelSN, wifiMac: wifiMac, leftMAC: leftMAC, rightMAC: rightMAC, caseMAC: caseMAC)
    }
    
    public func file(tcpIsReady manager: NVEasySDK.NVEasyFileManager) {
        // TCP连接就绪回调
    }
    
    
    // MARK: - Audio Data Callbacks
    
    /// 接收到 OPUS 编码的音频数据
    /// - Parameters:
    ///   - manager: BLE 管理器实例
    ///   - opusData: OPUS 编码的音频数据
    ///   - framSize: 帧大小
    public func ble(manager: NVEasySDK.NVEasyBLEManager, didReceiveOPUS opusData: Data, framSize: Int32) {
        // 委托给音频处理管理器处理
        audioProcessingDelegateManager.handleRealTimeOPUSData(manager: manager, opusData: opusData, framSize: framSize)
    }
    
    public func ble(manager: NVEasySDK.NVEasyBLEManager, didResponse action: String, isSuccess: Bool, params: [Any]?) {
        commandHandler.handleCommandResponse(manager: manager, action: action, isSuccess: isSuccess, params: params)
    }
    
    // MARK: - File Transfer Callbacks
    
    /// 蓝牙文件传输完成回调
    /// - Parameters:
    ///   - manager: 文件管理器实例
    ///   - isFinish: 是否完成
    ///   - fileSN: 文件序列号
    ///   - error: 错误信息（如果有）
    public func file(manager: NVEasySDK.NVEasyFileManager, bleDidFinish isFinish: Bool, fileSN: Int, error: (any Error)?) {
        // 委托给文件传输管理器处理
        fileTransferDelegateManager.handleBluetoothFileTransferFinish(manager: manager, isFinish: isFinish, fileSN: fileSN, error: error)
    }
    
    /// WiFi 文件传输完成回调
    /// - Parameters:
    ///   - manager: 文件管理器实例
    ///   - isFinish: 是否完成
    ///   - fileSN: 文件序列号
    ///   - error: 错误信息（如果有）
    public func file(manager: NVEasySDK.NVEasyFileManager, WiFiDidFinish isFinish: Bool, fileSN: Int, error: (any Error)?) {
        // 委托给文件传输管理器处理
        fileTransferDelegateManager.handleWiFiFileTransferFinish(manager: manager, isFinish: isFinish, fileSN: fileSN, error: error)
    }
    
    // MARK: - OTA Update Callbacks
    
    /// OTA 升级开始回调
    /// - Parameter otaManager: OTA 管理器实例
    public func otaManager(didStart otaManager: NVEasyOTAManager) {
        // 委托给OTA升级管理器处理
        otaDelegateManager.handleOTAStart(otaManager: otaManager)
    }
    
    /// OTA 升级结束回调
    /// - Parameter otaManager: OTA 管理器实例
    public func otaManager(didEnd otaManager: NVEasyOTAManager) {
        // 委托给OTA升级管理器处理
        otaDelegateManager.handleOTAEnd(otaManager: otaManager)
    }
    
    /// OTA 升级进度回调
    /// - Parameters:
    ///   - otaManager: OTA 管理器实例
    ///   - progress: 升级进度 (0.0 - 1.0)
    ///   - error: 错误信息（如果有）
    public func otaManager(_ otaManager: NVEasyOTAManager, progress: Double, error: (any Error)?) {
        // 委托给OTA升级管理器处理
        otaDelegateManager.handleOTAProgress(otaManager: otaManager, progress: progress, error: error)
    }
    
    // MARK: - File Data Callbacks
    
    /// 蓝牙文件传输过程中接收到 OPUS 数据
    /// - Parameters:
    ///   - manager: 文件管理器实例
    ///   - opusData: OPUS 编码的音频数据
    ///   - fileSN: 文件序列号
    ///   - totalPkgCount: 总包数
    ///   - pkgNum: 当前包号
    public func file(manager: NVEasyFileManager, bleDidReceiveOPUS opusData: Data, fileSN: Int, totalPkgCount: Int, pkgNum: Int) {
        // 委托给文件传输管理器处理
        fileTransferDelegateManager.handleBluetoothFileTransferData(manager: manager, opusData: opusData, fileSN: fileSN, totalPkgCount: totalPkgCount, pkgNum: pkgNum)
    }
    
    /// WiFi 文件传输过程中接收到 OPUS 数据
    /// - Parameters:
    ///   - manager: 文件管理器实例
    ///   - opusData: OPUS 编码的音频数据
    ///   - fileSN: 文件序列号
    ///   - totalPkgCount: 总包数
    ///   - pkgNum: 当前包号
    public func file(manager: NVEasyFileManager, WiFiDidReceiveOPUS opusData: Data, fileSN: Int, totalPkgCount: Int, pkgNum: Int) {
        // 委托给文件传输管理器处理
        fileTransferDelegateManager.handleWiFiFileTransferData(manager: manager, opusData: opusData, fileSN: fileSN, totalPkgCount: totalPkgCount, pkgNum: pkgNum)
    }
    
    /// 接收到设备文件列表
    /// - Parameters:
    ///   - manager: 文件管理器实例
    ///   - files: 文件信息数组
    public func file(manager: NVEasyFileManager, didReceiveFiles files: [NVEasyFileInfo]) {
        // 委托给文件传输管理器处理
        fileTransferDelegateManager.handleFileListReceived(manager: manager, files: files)
    }
    
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
    public func file(manager: NVEasyFileManager, WiFiDidOpen isOpen: Bool, hwIP: String, hwPort: String, appIP: String, appPort: String, softAPSSID: String, softAPPassword: String) {
        // 委托给文件传输管理器处理
        fileTransferDelegateManager.handleWiFiHotspotOpen(manager: manager, isOpen: isOpen, hwIP: hwIP, hwPort: hwPort, appIP: appIP, appPort: appPort, softAPSSID: softAPSSID, softAPPassword: softAPPassword)
    }
    
    // MARK: - Status Handlers
    
    public func ble(manager: NVEasyBLEManager, didUpdateState state: NVEasyBLEManager.State, isConnected: Bool) {
        deviceStatusDelegateManager.handleStateUpdate(manager: manager, state: state, isConnected: isConnected)
    }
    
    public func ble(manager: NVEasyBLEManager, didUpdateBattery left: UInt, right: UInt, caseBattery: UInt) {
        deviceStatusDelegateManager.handleBatteryUpdate(manager: manager, left: left, right: right, caseBattery: caseBattery)
    }
    
    public func ble(manager: NVEasyBLEManager, didReceiveSoftwareVersion software: String, hardwareVersion hardware: String) {
        deviceStatusDelegateManager.handleVersionInfo(manager: manager, software: software, hardware: hardware)
    }
    
    public func ble(manager: NVEasyBLEManager, didUpdateBound isSuccess: Bool, isBound: Bool) {
        deviceStatusDelegateManager.handleBoundStatusUpdate(manager: manager, isSuccess: isSuccess, isBound: isBound)
    }
    
    public func ble(manager: NVEasyBLEManager, didUpdateMemory emptySizeOfKB: Int, totalSizeOfKB: Int, isFormatSuccess: Bool?) {
        deviceStatusDelegateManager.handleMemoryUpdate(manager: manager, emptySizeOfKB: emptySizeOfKB, totalSizeOfKB: totalSizeOfKB, isFormatSuccess: isFormatSuccess)
    }
    
    public func ble(manager: NVEasyBLEManager, didUpdateVolume volume: UInt) {
        deviceStatusDelegateManager.handleVolumeUpdate(manager: manager, volume: volume)
    }
    
    public func ble(manager: NVEasyBLEManager, didUpdatePlayState state: NVEasyPlayState) {
        deviceStatusDelegateManager.handlePlayStateUpdate(manager: manager, state: state)
    }
    
    public func ble(manager: NVEasyBLEManager, didUpdateAnc anc: NVEasyANCOption) {
        deviceStatusDelegateManager.handleAncUpdate(manager: manager, anc: anc)
    }
    
    public func ble(manager: NVEasyBLEManager, didUpdateEq eq: NVEasyEQOption) {
        deviceStatusDelegateManager.handleEqUpdate(manager: manager, eq: eq)
    }
    
    public func ble(manager: NVEasyBLEManager, didUpdateCallState state: NVEasyCallState, callNumber: String?) {
        deviceStatusDelegateManager.handleCallStateUpdate(manager: manager, state: state, callNumber: callNumber)
    }
    
    
    public func ble(manager: NVEasyBLEManager, didReceiveAlg key: Data) {
        deviceStatusDelegateManager.handleAlgorithmKey(manager: manager, key: key)
    }
    
    public func ble(manager: NVEasyBLEManager, error: Error) {
        deviceStatusDelegateManager.handleError(manager: manager, error: error)
    }
    
    public func ble(manager: NVEasyBLEManager, didUpdateDevrec action: NVEasyDevrecAction, mode: NVEasyRecordMode?, aiMode: NVEasyAIMode) {
        commandHandler.handleDeviceRecordStatusUpdate(manager: manager, action: action, mode: mode, aiMode: aiMode)
    }
    
}

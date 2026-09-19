import Foundation
import NVEasySDK
import CoreBluetooth

protocol FileOperationDelegate: AnyObject {
    func fileManager(_ manager: NVFileManager, didReceiveFiles files: [NVEasyFileInfo])
    func fileManager(_ manager: NVFileManager, didFinishTransfer fileSN: Int, error: Error?)
    func fileManager(_ manager: NVFileManager, didOpenWiFi hwIP: String, hwPort: String, appIP: String, appPort: String, softAPSSID: String, softAPPassword: String)
}

public class NVFileManager: NSObject, FileManagerProtocol {
    
    // MARK: - Singleton
    static let shared = NVFileManager()
    
    private var easyUDP: NVEasyUDP?
    weak var delegate: FileOperationDelegate?
    
    // WiFi快传相关状态
    private var isWifiTransferEnabled = false
    private var currentWifiFileSN: Int?
    
    private override init() {
        super.init()
    }
    
    public func getFileList() {
        NVEasyBLEManager.shared.getFileList()
    }
    
    public func downloadFile(sn: Int, useWifi: Bool = false) {
        // 检查是否有断点续传状态
        if let transferState = ResumeTransferManager.shared.getTransferState(fileSN: sn) as? ResumeTransferManager.TransferState,
           transferState.canResume {
            // 使用断点续传
            let offsetInBytes = transferState.receivedBytes
            BLELogger.log("🔄 [断点续传] 文件 \(sn) 从字节 \(offsetInBytes) 开始续传")
            NVEasyFileManager.shared.getFile(sn: sn, useWiFi: useWifi, autoDelete: true, offsetInBytes: offsetInBytes)
        } else {
            // 从头开始下载
            NVEasyFileManager.shared.getFile(sn: sn, useWiFi: useWifi, autoDelete: true, offsetInBytes: 0)
        }
    }
    
    /// 下载文件（指定偏移量）
    /// - Parameters:
    ///   - sn: 文件序列号
    ///   - offsetInBytes: 偏移量（字节）
    public func downloadFile(sn: Int, offsetInBytes: Int, useWifi: Bool = false) {
        BLELogger.log("📁 [文件下载] 下载文件 \(sn)，偏移量: \(offsetInBytes) 字节")
        if !useWifi {
            NVEasyFileManager.shared.getFile(sn: sn, useWiFi: false, autoDelete: true, offsetInBytes: offsetInBytes)
        } else {
            NVEasyFileManager.shared.getFile(sn: sn, useWiFi: useWifi, autoDelete: true, offsetInBytes: offsetInBytes)
        }
        
    }
    
//    public func downloadFileByWifi(sn: Int) {
//        // WiFi快传下载实现
//        print("开始WiFi快传下载文件: \(sn)")
//        
//        // 1. 检查是否有文件列表
//        let files = NVEasyFileManager.shared.files
//        guard !files.isEmpty else {
//            print("没有可下载的文件列表")
//            return
//        }
//        
//        // 2. 查找目标文件
//        guard let targetFile = files.first(where: { $0.sn == sn }) else {
//            print("未找到SN为\(sn)的文件")
//            return
//        }
//        
//        // 3. 设置当前WiFi文件SN
//        currentWifiFileSN = sn
//        
//        // 4. 设置WiFi快传状态
//        isWifiTransferEnabled = true
//        
//        // 5. 开启WiFi热点
//        NVEasyBLEManager.shared.fileManager.getFile(sn: sn, useWiFi: true, offsetInBytes: nil)
//    }
    
    public func closeWiFi() {
        print("关闭WiFi快传")
        isWifiTransferEnabled = false
        currentWifiFileSN = nil
        
        if let easyUDP = self.easyUDP {
            easyUDP.stopConnection()
            self.easyUDP = nil
        }
        
        if let closeWiFiCmd = NVEasyFileManager.shared.closeWiFi() {
            DispatchQueue.main.async {
                self.sendUDP(data: closeWiFiCmd)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func connetUDP(hwIP: String, hwPort: String, appIP: String, appPort: String) {
        if let easyUDP = self.easyUDP {
            easyUDP.stopConnection()
            self.easyUDP = nil
        }
        
        easyUDP = NVEasyUDP(targetIP: hwIP,
                           targetPort: UInt16(hwPort) ?? 0,
                           localIP: appIP,
                           localPort: UInt16(appPort) ?? 0)
        
        setupUDPConnection()
    }
    
    private func setupUDPConnection() {
        easyUDP?.setStateUpdateHandler { [weak self] state in
            switch state {
            case .ready:
                self?.sendStartWiFiTransferCmd()
            case .failed(let error):
                print("UDP Connection failed: \(error)")
            case .cancelled:
                print("UDP Connection cancelled")
            case .waiting(let error):
                print("UDP Connection waiting: \(error)")
            case .preparing:
                print("UDP Connection preparing")
            case .setup:
                print("UDP Connection setup")
            @unknown default:
                print("UDP Connection unknown state")
            }
        }
        
        easyUDP?.startConnection(receiveData: { [weak self] receivedData in
            self?.receiveUDP(data: receivedData)
        }) { error in
            print("UDP Error: \(error)")
        }
    }
    
    private func sendStartWiFiTransferCmd() {
        print("发送WiFi快传开始命令")
        
        // 设置重试处理器
        NVEasyFileManager.shared.retryHandler = { [weak self] data in
            self?.sendUDP(data: data)
        }
        
        // 开始传输当前文件
        if let fileSN = currentWifiFileSN {
            let startCmd = NVEasyFileManager.shared.startWiFiTransferCmd(sn: fileSN,
                                                                       autoDelete: true,
                                                                       offsetInBytes: 0)
            sendUDP(data: startCmd)
        }
    }
    
    private func sendUDP(data: Data) {
        easyUDP?.sendData(data)
    }
    
    private func receiveUDP(data: Data) {
        if let nextCmd = NVEasyFileManager.shared.didReceiveWifiCmd(data) {
            self.sendUDP(data: nextCmd)
        }
    }
    
    private func handleWiFiTransferError(_ error: Error) {
        print("WiFi传输错误: \(error)")
        isWifiTransferEnabled = false
        currentWifiFileSN = nil
        
        // 通知Flutter端传输失败
        let arguments: [String: Any] = [
            "isFinish": false,
            "fileSN": currentWifiFileSN ?? 0,
            "error": error.localizedDescription
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("wifiDidGetFile", arguments: arguments)
    }
}

// MARK: - NVEasyHardwareDelegate Proxy
extension NVFileManager {
    func handleFileReceived(files: [NVEasyFileInfo]) {
        let arguments = files.map { file in
            [
                "sn": file.sn,
                "name": file.name,
                "size": file.size,
                "scene": file.scene,
                "startTimestamp": Int(file.startTimestamp),
                "endTimestamp": Int(file.endTimestamp)
            ]
        }
        NVEasyPlugin.methodChannel?.invokeMethod("didReceiveFiles", arguments: arguments)
        delegate?.fileManager(self, didReceiveFiles: files)
//        NVEasyPlugin.shared.files = files
    }
    
    func handleFileTransferFinished(fileSN: Int, error: Error?) {
        print("文件传输完成: \(fileSN), 错误: \(error?.localizedDescription ?? "无")")
        
        // 停止UDP连接
        easyUDP?.stopConnection()
        easyUDP = nil
        
        // 清理WiFi传输状态
        isWifiTransferEnabled = false
        currentWifiFileSN = nil
        
        delegate?.fileManager(self, didFinishTransfer: fileSN, error: error)
        
        // 通知Flutter端传输完成
        let arguments: [String: Any] = [
            "isFinish": error == nil,
            "fileSN": fileSN,
            "error": error?.localizedDescription ?? ""
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("wifiDidGetFile", arguments: arguments)
    }
    
    func handleWiFiOpen(hwIP: String, hwPort: String, appIP: String, appPort: String, softAPSSID: String, softAPPassword: String) {
        print("WiFi热点开启: \(softAPSSID)")
        print("硬件IP: \(hwIP):\(hwPort), 应用IP: \(appIP):\(appPort)")
        
        // 延迟30秒后建立UDP连接（给用户时间连接WiFi热点）
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            self.connetUDP(hwIP: hwIP, hwPort: hwPort, appIP: appIP, appPort: appPort)
        }
        
        delegate?.fileManager(self, didOpenWiFi: hwIP, hwPort: hwPort, appIP: appIP, appPort: appPort, softAPSSID: softAPSSID, softAPPassword: softAPPassword)
        
        // 通知Flutter端WiFi状态
        let arguments: [String: Any] = [
            "wifiStatus": 1, // OPENED
            "softAPSSID": softAPSSID,
            "softAPPassword": softAPPassword
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("deviceWifiStatus", arguments: arguments)
    }
    
    // MARK: - FileManagerProtocol Methods
    
    /// 通过蓝牙下载所有文件
    /// - Parameter files: 文件列表
    public func downloadAllFilesViaBluetooth(files: [NVEasyFileInfo]) {
        BLELogger.log("📁 [文件管理] 开始通过蓝牙下载所有文件，共 \(files.count) 个文件")
        
        // 这里应该实现批量下载逻辑
        // 目前先记录日志
        for file in files {
            BLELogger.log("📁 [文件管理] 准备下载文件: \(file.name), SN: \(file.sn)")
        }
    }
    
    /// 停止串行下载
    public func stopSerialDownload() {
        BLELogger.log("📁 [文件管理] 停止串行下载")
        
        // 这里应该实现停止下载的逻辑
        // 目前先记录日志
    }
} 

import Foundation
import CoreBluetooth
import NVEasySDK
import Flutter

/// BLE连接处理器
/// 负责处理BLE设备的连接、断开、发现等事件
class BLEConnectionHandler {
    
    // MARK: - Properties
    
    private weak var bleManager: BLEManager?
    
    // MARK: - Initialization
    
    init(bleManager: BLEManager) {
        self.bleManager = bleManager
    }
    
    // MARK: - Connection Methods
    
    /// 处理设备连接失败
    /// - Parameters:
    ///   - manager: BLE管理器实例
    ///   - peripheral: 连接失败的设备
    ///   - error: 错误信息
    func handleConnectionFailure(manager: NVEasyBLEManager, peripheral: CBPeripheral, error: Error?) {
        let uuid = peripheral.mac
        BLELogger.error("❌ [设备连接] 连接失败: \(peripheral.name ?? "未知"), MAC: \(uuid), 错误: \(error?.localizedDescription ?? "无")")
        
        sendBluetoothConnectionFailure(uuid: uuid)
    }
    
    /// 处理设备断开连接
    /// - Parameters:
    ///   - manager: BLE管理器实例
    ///   - peripheral: 断开的设备
    ///   - error: 断开原因
    func handleDisconnection(manager: NVEasyBLEManager, peripheral: CBPeripheral, error: Error?) {
        BLELogger.log("🔌 [设备断开] 设备断开连接: \(peripheral.name ?? "未知"), MAC: \(peripheral.mac), 错误: \(error?.localizedDescription ?? "无")")

        // 准备断开连接参数
        let arguments: [String: Any?] = [
            "uuid": peripheral.mac,
            "name": peripheral.name
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("didDisconnect", arguments: arguments)

        // 根据不同的管理器实例清理设备引用
        guard let bleManager = bleManager else { return }
        
        switch manager {
        case NVEasyBLEManager.shared:
            bleManager.firstPeripheral = nil
            BLELogger.log("🔌 [设备断开] 清理主设备引用")
        case NVEasyBLEManager.sharedExA:
            bleManager.secondPeripheral = nil
            BLELogger.log("🔌 [设备断开] 清理第二个设备引用")
        case NVEasyBLEManager.sharedExB:
            bleManager.thirdPeripheral = nil
            BLELogger.log("🔌 [设备断开] 清理第三个设备引用")
        default:
            BLELogger.log("🔌 [设备断开] 未知管理器实例")
            break
        }
    }
    
    /// 处理设备连接成功
    /// - Parameters:
    ///   - manager: BLE管理器实例
    ///   - peripheral: 连接的设备
    func handleConnectionSuccess(manager: NVEasyBLEManager, peripheral: CBPeripheral) {
        BLELogger.log("🔗 [设备连接] 连接成功: \(peripheral.name ?? "未知"), MAC: \(peripheral.mac)")
        
        // 准备连接成功参数
        let arguments: [String: Any?] = [
            "uuid": peripheral.mac,
            "name": peripheral.name
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("didConnect", arguments: arguments)
        
        // 根据不同的管理器实例初始化多设备连接
        switch manager {
        case NVEasyBLEManager.shared:
            BLELogger.log("🔗 [设备连接] 主设备连接成功，初始化第二个设备连接")
        case NVEasyBLEManager.sharedExA:
            BLELogger.log("🔗 [设备连接] 第二个设备连接成功，初始化第三个设备连接")
        default:
            BLELogger.log("🔗 [设备连接] 未知管理器实例")
            break
        }
        
        // 停止扫描
        bleManager?.stopScan()
        
        // 两秒后执行获取电量
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, let bleManager = self.bleManager else { return }
            
            // 检查连接状态，确保设备仍然连接
            if NVEasyBLEManager.shared.isConnected {
                BLELogger.log("🔋 [自动获取电量] 设备连接成功2秒后，自动获取电量")
                bleManager.getBattery()
            } else {
                BLELogger.warning("⚠️ [自动获取电量] 设备已断开连接，跳过获取电量")
            }
        }
    }
    
    /// 处理RSSI读取
    /// - Parameters:
    ///   - manager: BLE管理器实例
    ///   - peripheral: 设备
    ///   - rssi: RSSI值
    func handleRSSIRead(manager: NVEasyBLEManager, peripheral: CBPeripheral, rssi: NSNumber) {
        let arguments: [String: Any?] = [
            "uuid": peripheral.mac,
            "rssi": rssi
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("didReadRSSI", arguments: arguments)
    }
    
    // MARK: - Device Discovery Methods
    
    /// 处理设备发现过滤
    /// - Parameters:
    ///   - manager: BLE管理器实例
    ///   - peripheral: 发现的设备
    ///   - advertisementData: 广播数据
    /// - Returns: 是否应该发现该设备
    func shouldDiscoverDevice(manager: NVEasyBLEManager, peripheral: CBPeripheral, advertisementData: [String: Any]) -> Bool {
        BLELogger.log("🔍 [设备发现] 检查设备: \(peripheral.name ?? "未知"), MAC: \(peripheral.mac)")
        
        // 检查设备是否可连接
        guard
            let isConnectable = advertisementData["kCBAdvDataIsConnectable"] as? NSNumber,
            isConnectable.boolValue,
            let advDataLocalName = advertisementData["kCBAdvDataLocalName"] as? String,
            !advDataLocalName.isEmpty,
            let peripheralName = peripheral.name,
            !peripheralName.isEmpty
        else {
            BLELogger.error("❌ [设备发现] 设备不符合连接条件")
            return false
        }
        
        // 检查制造商数据以过滤特定设备
        if let manufacturerData = advertisementData["kCBAdvDataManufacturerData"] as? Data,
           manufacturerData.count >= 0x10 {
            let bytes = Array(manufacturerData)
            
            // 检查 "NvEasy" 标识
            let idMark0 = "NvEasy"
            let filterString0 = idMark0.map { $0.asciiValue! }
            if bytes[9...14].elementsEqual(filterString0) {
                BLELogger.success("✅ [设备发现] 发现NvEasy设备")
                return true
            }
            
            // 检查 "GLBTK" 标识
            let idMark1 = "GLBTK"
            let filterString1 = idMark1.map { $0.asciiValue! }
            if bytes[9...14].elementsEqual(filterString1) {
                BLELogger.success("✅ [设备发现] 发现GLBTK设备")
                return true
            }
        }
        
        BLELogger.error("❌ [设备发现] 设备不符合制造商标识要求")
        return false
    }
    
    /// 处理设备发现
    /// - Parameters:
    ///   - manager: BLE管理器实例
    ///   - peripheral: 发现的设备
    func handleDeviceDiscovery(manager: NVEasyBLEManager, peripheral: CBPeripheral) {
        BLELogger.log("🔍 [设备发现] 发现设备: \(peripheral.name ?? "未知"), MAC: \(peripheral.mac)")
        
        // 准备设备信息参数
        let arguments: [String: Any?] = [
            "uuid": peripheral.mac,
            "name": peripheral.name
        ]
        
        guard let bleManager = bleManager else { return }
        
        // 根据不同的管理器实例处理设备发现
        switch manager {
        case NVEasyBLEManager.shared:
            bleManager.peripheralMap[peripheral.mac] = peripheral
            NVEasyPlugin.methodChannel?.invokeMethod("didDiscover", arguments: arguments)
            BLELogger.log("🔍 [设备发现] 主管理器处理第一个设备")
            
        case NVEasyBLEManager.sharedExA:
            // 扩展管理器A：处理第二个设备
            if !manager.isConnected {
                bleManager.peripheralMapA[peripheral.mac] = peripheral
                NVEasyPlugin.methodChannel?.invokeMethod("didDiscover", arguments: arguments)
                BLELogger.log("🔍 [设备发现] 扩展管理器A处理第二个设备")
            }
            
        case NVEasyBLEManager.sharedExB:
            // 扩展管理器B：处理第三个设备
            if !manager.isConnected {
                bleManager.peripheralMapB[peripheral.mac] = peripheral
                NVEasyPlugin.methodChannel?.invokeMethod("didDiscover", arguments: arguments)
                BLELogger.log("🔍 [设备发现] 扩展管理器B处理第三个设备")
            }
            
        default:
            BLELogger.log("🔍 [设备发现] 未知管理器实例")
            break
        }
    }
    
    // MARK: - Private Methods
    
    /// 发送蓝牙连接失败通知
    /// - Parameter uuid: 设备UUID
    private func sendBluetoothConnectionFailure(uuid: String) {
        let arguments: [String: Any] = [
            "uuid": uuid,
            "linkstatus": 1
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("blueTurnOff", arguments: arguments)
    }
}

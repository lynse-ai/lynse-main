import Foundation
import NVEasySDK

/// OTA升级委托管理器
/// 负责处理所有OTA升级相关的回调事件
class OTADelegateManager: OTADelegateManagerProtocol {
    
    // MARK: - Singleton
    static let shared = OTADelegateManager()
    
    // MARK: - Properties
    
    /// 访问锁
    private let otaLock = NSLock()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - OTA Update Callbacks
    
    /// OTA 升级开始回调
    /// - Parameter otaManager: OTA 管理器实例
    func handleOTAStart(otaManager: NVEasyOTAManager) {
        NVEasyLogger.info("🔄 [OTA升级] 开始升级")
        
        // 发送升级开始状态到Flutter端（对应Android的STARTED状态）
        let arguments: [String: Any] = [
            "status": 0, // STARTED
            "progress": 0,
            "upgradedSize": 0,
            "error": ""
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("deviceUpdateOtaStatus", arguments: arguments)
    }
    
    /// OTA 升级结束回调
    /// - Parameter otaManager: OTA 管理器实例
    func handleOTAEnd(otaManager: NVEasyOTAManager) {
        NVEasyLogger.success("✅ [OTA升级] 升级完成")
        
        // 发送升级成功状态到Flutter端（对应Android的SUCCESS状态）
        let arguments: [String: Any] = [
            "status": 2, // SUCCESS
            "progress": 100,
            "upgradedSize": 0,
            "error": ""
        ]
        NVEasyPlugin.methodChannel?.invokeMethod("deviceUpdateOtaStatus", arguments: arguments)
    }
    
    /// OTA 升级进度回调
    /// - Parameters:
    ///   - otaManager: OTA 管理器实例
    ///   - progress: 升级进度 (0.0 - 1.0)
    ///   - error: 错误信息（如果有）
    func handleOTAProgress(otaManager: NVEasyOTAManager, progress: Double, error: Error?) {
        if let error = error {
            NVEasyLogger.error("❌ [OTA升级] 升级错误: \(error.localizedDescription)")
            
            // 发送升级失败状态到Flutter端（对应Android的FAILED状态）
            let arguments: [String: Any] = [
                "status": 3, // FAILED
                "progress": 0,
                "upgradedSize": 0,
                "error": error.localizedDescription
            ]
            NVEasyPlugin.methodChannel?.invokeMethod("deviceUpdateOtaStatus", arguments: arguments)
        } else {
            NVEasyLogger.info("🔄 [OTA升级] 进度: \(Int(progress * 100))%")
            
            // 发送升级进度状态到Flutter端（对应Android的PROGRESS状态）
            let arguments: [String: Any] = [
                "status": 1, // PROGRESS
                "progress": Int(progress * 100),
                "upgradedSize": 0, // iOS SDK没有提供已升级大小信息，设为0
                "error": ""
            ]
            NVEasyPlugin.methodChannel?.invokeMethod("deviceUpdateOtaStatus", arguments: arguments)
        }
    }
    
    // MARK: - Public Methods
    
    /// 获取OTA升级状态信息
    /// - Returns: OTA升级状态信息字典
    func getOTAStatusInfo() -> [String: Any] {
        return [
            "isUpgrading": false, // 需要根据实际状态更新
            "progress": 0,
            "error": ""
        ]
    }
    
    /// 重置OTA升级状态
    func resetOTAStatus() {
        NVEasyLogger.info("🔄 [OTA升级] 重置OTA升级状态")
    }
}

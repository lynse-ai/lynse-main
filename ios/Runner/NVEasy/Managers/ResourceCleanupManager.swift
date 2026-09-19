import Foundation

/// 资源清理管理器
class ResourceCleanupManager: ResourceCleanupManagerProtocol {
    
    // MARK: - Singleton
    
    static let shared = ResourceCleanupManager()
    
    // MARK: - Properties
    
    private var cleanupTasks: [() -> Void] = []
    private let queue = DispatchQueue(label: "com.nveasy.cleanup", qos: .utility)
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Public Methods
    
    /// 注册清理任务
    /// - Parameter task: 清理任务闭包
    func registerCleanupTask(_ task: @escaping () -> Void) {
        queue.async {
            self.cleanupTasks.append(task)
        }
    }
    
    /// 执行所有清理任务
    func performCleanup() {
        NVEasyLogger.info("🧹 开始执行资源清理")
        
        queue.sync {
            for (index, task) in cleanupTasks.enumerated() {
                do {
                    task()
                    NVEasyLogger.debug("清理任务 \(index + 1) 执行成功")
                } catch {
                    NVEasyLogger.error("清理任务 \(index + 1) 执行失败: \(error)")
                }
            }
            
            cleanupTasks.removeAll()
        }
        
        NVEasyLogger.info("🧹 资源清理完成")
    }
    
    /// 清理特定类型的资源
    /// - Parameter type: 资源类型
    func cleanupResource(type: String) {
        NVEasyLogger.info("🧹 开始清理 \(type) 资源")
        
        switch type {
        case "commandQueue":
            CommandQueueManager.shared.clearExecutionTimes()
            
        case "bleManager":
            BLEManager.shared.cleanupOnAppExit()
            
        case "audioManager":
            BLERecordManager.shared.cleanupAllTemporaryFiles()
            BLERecordManager.shared.cleanupDuplicateAudioFiles()
            
        case "transferManager":
            ResumeTransferManager.shared.clearCompletedTransfers()
            
        case "all":
            performCleanup()
            
        default:
            NVEasyLogger.warning("⚠️ 未知的资源类型: \(type)")
        }
        
        NVEasyLogger.info("🧹 \(type) 资源清理完成")
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.performCleanup()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            // 应用进入后台时执行轻量级清理
            self.cleanupResource(type: "commandQueue")
        }
    }
}

// MARK: - ResourceType

extension ResourceCleanupManager {
    enum ResourceType: String, CaseIterable {
        case commandQueue = "指令队列"
        case bleManager = "BLE管理器"
        case audioManager = "音频管理器"
        case transferManager = "传输管理器"
        case all = "所有资源"
    }
}

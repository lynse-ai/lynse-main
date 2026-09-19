import Foundation
import Flutter

/// 方法处理器管理器
/// 负责管理和协调所有方法处理器的执行
class MethodHandlerManager: MethodHandlerManagerProtocol {
    
    // MARK: - Properties
    
    private var handlers: [MethodHandlerProtocol] = []
    
    // MARK: - Initialization
    
    init(bleManager: BLEManager, fileManager: NVFileManager, audioManager: BLERecordManager) {
        NVEasyLogger.info("初始化方法处理器管理器")
        setupHandlers(bleManager: bleManager, fileManager: fileManager, audioManager: audioManager)
    }
    
    // MARK: - Setup
    
    private func setupHandlers(bleManager: BLEManager, fileManager: NVFileManager, audioManager: BLERecordManager) {
        // 按优先级注册处理器
        handlers = [
            SystemMethodHandler(),
            BLEMethodHandler(bleManager: bleManager),
            AudioMethodHandler(audioManager: audioManager),
            FileMethodHandler(fileManager: fileManager),
            TransferMethodHandler(),
            OTAMethodHandler()
        ]
        
        NVEasyLogger.info("已注册 \(handlers.count) 个方法处理器")
    }
    
    // MARK: - Public Methods
    
    /// 处理方法调用
    /// - Parameters:
    ///   - method: 方法名
    ///   - arguments: 参数
    ///   - result: 结果回调
    /// - Returns: 是否找到对应的处理器
    func handle(method: String, arguments: [String: Any]?, result: @escaping FlutterResult) -> Bool {
        NVEasyLogger.debug("查找方法处理器: \(method)")
        
        for (index, handler) in handlers.enumerated() {
            if handler.handle(method: method, arguments: arguments, result: result) {
                NVEasyLogger.debug("方法 \(method) 由处理器 \(index) 处理")
                return true
            }
        }
        
        NVEasyLogger.warning("未找到方法处理器: \(method)")
        return false
    }
    
    /// 获取已注册的处理器数量
    /// - Returns: 处理器数量
    func getHandlerCount() -> Int {
        return handlers.count
    }
    
    /// 获取处理器信息（用于调试）
    /// - Returns: 处理器信息数组
    func getHandlerInfo() -> [String] {
        return handlers.enumerated().map { index, handler in
            "\(index): \(type(of: handler))"
        }
    }
}

import Foundation
import Flutter

/// 错误处理管理器
class ErrorManager: ErrorManagerProtocol {
    
    // MARK: - Singleton
    
    static let shared = ErrorManager()
    
    // MARK: - Properties
    
    private let errorCodes = NVEasyConstants.ErrorCodes.self
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 处理并记录错误
    /// - Parameters:
    ///   - error: 错误对象
    ///   - context: 错误上下文
    ///   - result: Flutter结果回调
    func handleError(_ error: Error, context: String, result: @escaping FlutterResult) {
        let flutterError = createFlutterError(from: error, context: context)
        
        // 记录错误日志
        NVEasyLogger.error("错误处理 [\(context)]: \(error.localizedDescription)")
        
        // 发送错误事件
        NVEasyPluginStreamHandler.shared.sendError(error)
        
        // 返回Flutter错误
        result(flutterError)
    }
    
    /// 处理参数验证错误
    /// - Parameters:
    ///   - missingParameter: 缺失的参数名
    ///   - result: Flutter结果回调
    func handleParameterError(missingParameter: String, result: @escaping FlutterResult) {
        let error = FlutterError(
            code: errorCodes.invalidArguments,
            message: "Missing required parameter: \(missingParameter)",
            details: ["missingParameter": missingParameter]
        )
        
        NVEasyLogger.warning("参数验证失败: 缺失参数 \(missingParameter)")
        result(error)
    }
    
    /// 处理设备连接错误
    /// - Parameters:
    ///   - deviceId: 设备ID
    ///   - result: Flutter结果回调
    func handleConnectionError(deviceId: String, result: @escaping FlutterResult) {
        let error = FlutterError(
            code: errorCodes.connectionFailed,
            message: "Failed to connect to device: \(deviceId)",
            details: ["deviceId": deviceId]
        )
        
        NVEasyLogger.error("设备连接失败: \(deviceId)")
        result(error)
    }
    
    /// 处理设备未找到错误
    /// - Parameters:
    ///   - deviceId: 设备ID
    ///   - result: Flutter结果回调
    func handleDeviceNotFoundError(deviceId: String, result: @escaping FlutterResult) {
        let error = FlutterError(
            code: errorCodes.deviceNotFound,
            message: "Device not found: \(deviceId)",
            details: ["deviceId": deviceId]
        )
        
        NVEasyLogger.warning("设备未找到: \(deviceId)")
        result(error)
    }
    
    // MARK: - Private Methods
    
    public func createFlutterError(from error: Error, context: String) -> FlutterError {
        if let flutterError = error as? FlutterError {
            return flutterError
        }
        
        return FlutterError(
            code: NVEasyConstants.ErrorCodes.unknownError,
            message: error.localizedDescription,
            details: [
                "context": context,
                "errorType": String(describing: type(of: error))
            ]
        )
    }
}

// MARK: - Error Extensions

extension Error {
    /// 转换为Flutter错误
    func toFlutterError(context: String = "") -> FlutterError {
        return ErrorManager.shared.createFlutterError(from: self, context: context)
    }
}


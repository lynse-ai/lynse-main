import Flutter
import UIKit
import NVEasySDK
import Foundation

/// NVEasy Flutter插件主类
public class NVEasyPlugin: NSObject, FlutterPlugin {
    
    // MARK: - Static Properties
    
    static let shared = NVEasyPlugin()
    static var methodChannel: FlutterMethodChannel?
    static var eventChannel: FlutterEventChannel?
    
    // MARK: - Dependencies
    
    private let bleManager: BLEManager
    private let fileManager: NVFileManager
    private let audioManager: BLERecordManager
    private let commandQueueManager: CommandQueueManager
    private let methodHandlerManager: MethodHandlerManager
    private let resourceCleanupManager: ResourceCleanupManager
    private let errorManager: ErrorManager
    
    // MARK: - Initialization
    
    public override init() {
        // 初始化依赖
        self.bleManager = BLEManager.shared
        self.fileManager = NVFileManager.shared
        self.audioManager = BLERecordManager.shared
        self.commandQueueManager = CommandQueueManager.shared
        self.resourceCleanupManager = ResourceCleanupManager.shared
        self.errorManager = ErrorManager.shared
        
        self.methodHandlerManager = MethodHandlerManager(
            bleManager: bleManager,
            fileManager: fileManager,
            audioManager: audioManager
        )
        
        super.init()
        
        setupPlugin()
    }
    
    // MARK: - Setup
    
    private func setupPlugin() {
        NVEasyLogger.info("初始化NVEasy插件")
        
        // 委托已在BLEManager初始化时设置，无需重复设置
        // NVEasyBLEManager.shared.delegate = self.bleManager
        
        // 注册清理任务
        registerCleanupTasks()
        
        NVEasyLogger.info("NVEasy插件初始化完成")
    }
    
    private func registerCleanupTasks() {
        resourceCleanupManager.registerCleanupTask { [weak self] in
            self?.commandQueueManager.clearExecutionTimes()
        }
        
        resourceCleanupManager.registerCleanupTask { [weak self] in
            self?.bleManager.cleanupOnAppExit()
        }
        
        resourceCleanupManager.registerCleanupTask { [weak self] in
            self?.audioManager.cleanupAllTemporaryFiles()
            self?.audioManager.cleanupDuplicateAudioFiles()
        }
        
        resourceCleanupManager.registerCleanupTask {
            ResumeTransferManager.shared.clearCompletedTransfers()
        }
    }
    
    // MARK: - Flutter Plugin Registration
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        NVEasyLogger.info("注册NVEasy Flutter插件")
        
        // 创建方法通道
        let channel = FlutterMethodChannel(
            name: NVEasyConstants.methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        
        // 创建事件通道
        let eventChannel = FlutterEventChannel(
            name: NVEasyConstants.eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        
        // 创建插件实例
        let instance = NVEasyPlugin()
        
        // 设置静态属性
        methodChannel = channel
        self.eventChannel = eventChannel
        
        // 注册方法调用代理
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // 设置事件流处理器
        eventChannel.setStreamHandler(NVEasyPluginStreamHandler.shared)
        
        NVEasyLogger.info("NVEasy Flutter插件注册完成")
    }
    
    // MARK: - Method Handling
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        NVEasyLogger.debug("处理方法调用: \(call.method)")
        
        // 检查指令防抖
        if let commandType = CommandType(rawValue: call.method) {
            if commandQueueManager.shouldDebounceCommand(type: call.method) {
                NVEasyLogger.warning("指令 \(call.method) 被防抖过滤")
                result("\(call.method) debounced!")
                return
            } else {
                // 更新最后执行时间
                commandQueueManager.updateLastExecutionTime(type: call.method)
            }
        }
        
        // 使用方法处理器管理器处理请求
        let arguments = call.arguments as? [String: Any]
        
        do {
            if !methodHandlerManager.handle(method: call.method, arguments: arguments, result: result) {
                NVEasyLogger.warning("未找到方法处理器: \(call.method)")
                result(FlutterMethodNotImplemented)
            }
        } catch {
            NVEasyLogger.error("方法处理失败: \(call.method), 错误: \(error)")
            errorManager.handleError(error, context: "method_\(call.method)", result: result)
        }
    }
    
    
    // MARK: - Cleanup
    
    /// 应用退出时的清理
    @objc private func cleanupOnAppExit() {
        NVEasyLogger.info("应用退出，开始清理资源")
        resourceCleanupManager.performCleanup()
    }
    
    /// 析构函数
    deinit {
        NVEasyLogger.debug("NVEasyPlugin 析构")
        resourceCleanupManager.performCleanup()
    }
} 

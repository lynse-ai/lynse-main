import Foundation

/// NVEasy 插件常量定义
/// 统一管理项目中使用的所有常量
enum NVEasyConstants {
    
    // MARK: - Flutter Channel Names
    
    /// Flutter 方法通道名称
    static let methodChannelName = "nv_easy_plugin/methods"
    
    /// Flutter 事件通道名称
    static let eventChannelName = "nv_easy_plugin/events"
    
    // MARK: - Error Codes
    
    /// 错误代码定义
    enum ErrorCodes {
        static let invalidArguments = "INVALID_ARGUMENTS"
        static let deviceNotFound = "DEVICE_NOT_FOUND"
        static let connectionFailed = "CONNECTION_FAILED"
        static let unknownError = "UNKNOWN_ERROR"
        static let operationFailed = "OPERATION_FAILED"
        static let timeout = "TIMEOUT"
        static let permissionDenied = "PERMISSION_DENIED"
        static let invalidState = "INVALID_STATE"
    }
    
    // MARK: - BLE States
    
    /// BLE 状态枚举
    enum BLEState: String, CaseIterable {
        case ready = "ready"
        case connecting = "connecting"
        case connected = "connected"
        case disconnected = "disconnected"
        case paused = "paused"
        case recording = "recording"
        case uploading = "uploading"
        case poweredOff = "poweredOff"
        case poweredOn = "poweredOn"
        case resetting = "resetting"
        case unsupported = "unsupported"
        case unauthorized = "unauthorized"
        case unknown = "unknown"
        
        /// 获取状态描述
        var description: String {
            switch self {
            case .ready: return "就绪"
            case .connecting: return "连接中"
            case .connected: return "已连接"
            case .disconnected: return "已断开"
            case .paused: return "已暂停"
            case .recording: return "录音中"
            case .uploading: return "上传中"
            case .poweredOff: return "蓝牙关闭"
            case .poweredOn: return "蓝牙开启"
            case .resetting: return "重置中"
            case .unsupported: return "不支持"
            case .unauthorized: return "未授权"
            case .unknown: return "未知状态"
            }
        }
    }
    
    // MARK: - File Paths
    
    /// 文件路径常量
    enum FilePaths {
        /// 音频数据存储路径
        static let audioDataPath = "audio_data"
        
        /// 传输状态存储文件名
        static let transferStatesFileName = "transfer_states.json"
        
        /// 音频文件前缀
        static let audioFilePrefix = "audio_"
        
        /// 音频文件后缀
        static let audioFileSuffix = ".data"
        
        /// PCM 文件后缀
        static let pcmFileSuffix = ".pcm"
        
        /// 实时音频文件前缀
        static let realtimeAudioPrefix = "realtime_audio_"
    }
    
    // MARK: - Memory Limits
    
    /// 内存限制常量
    enum MemoryLimits {
        /// 实时音频数据内存缓存最大大小（5MB）
        static let maxRealtimeMemorySize = 5 * 1024 * 1024
        
        /// 实时音频数据清理阈值（3MB）
        static let realtimeCleanupThreshold = 3 * 1024 * 1024
        
        /// 文件音频数据内存缓存最大大小（50MB）
        static let maxFileAudioMemorySize = 50 * 1024 * 1024
        
        /// 文件写入缓冲区大小（1MB）
        static let fileWriteBufferSize = 1024 * 1024
    }
    
    // MARK: - Time Intervals
    
    /// 时间间隔常量
    enum TimeIntervals {
        /// 默认超时时间（30秒）
        static let defaultTimeout: TimeInterval = 30.0
        
        /// 连接超时时间（10秒）
        static let connectionTimeout: TimeInterval = 10.0
        
        /// 文件传输超时时间（60秒）
        static let fileTransferTimeout: TimeInterval = 60.0
        
        /// 音频处理超时时间（5秒）
        static let audioProcessingTimeout: TimeInterval = 5.0
    }
    
    // MARK: - Logging
    
    /// 日志相关常量
    enum Logging {
        /// 日志子系统标识
        static let subsystem = "com.nveasy.plugin"
        
        /// 日志分类标识
        static let category = "NVEasyPlugin"
        
        /// 日志标签
        enum Tags {
            static let ble = "BLE"
            static let audio = "Audio"
            static let file = "File"
            static let transfer = "Transfer"
            static let error = "Error"
            static let debug = "Debug"
        }
    }
    
    // MARK: - Audio Settings
    
    /// 音频设置常量
    enum AudioSettings {
        /// 默认采样率
        static let defaultSampleRate: Int = 16000
        
        /// 默认声道数
        static let defaultChannels: Int = 2
        
        /// 默认位深度
        static let defaultBitDepth: Int = 16
        
        /// 音频缓冲区大小
        static let audioBufferSize: Int = 4096
    }
    
    // MARK: - BLE Settings
    
    /// BLE 设置常量
    enum BLESettings {
        /// 最大重连次数
        static let maxReconnectAttempts: Int = 3
        
        /// 重连间隔（秒）
        static let reconnectInterval: TimeInterval = 2.0
        
        /// 扫描超时时间（秒）
        static let scanTimeout: TimeInterval = 10.0
        
        /// 连接超时时间（秒）
        static let connectTimeout: TimeInterval = 10.0
    }
    
    // MARK: - File Transfer Settings
    
    /// 文件传输设置常量
    enum FileTransferSettings {
        /// 最大并发传输数
        static let maxConcurrentTransfers: Int = 3
        
        /// 传输重试次数
        static let maxRetryAttempts: Int = 3
        
        /// 重试间隔（秒）
        static let retryInterval: TimeInterval = 1.0
        
        /// 分片大小（字节）
        static let chunkSize: Int = 1024
    }
    
    // MARK: - Notification Names
    
    /// 通知名称常量
    enum NotificationNames {
        /// 设备连接状态变化
        static let deviceConnectionChanged = "NVEasyDeviceConnectionChanged"
        
        /// 音频状态变化
        static let audioStatusChanged = "NVEasyAudioStatusChanged"
        
        /// 文件传输状态变化
        static let fileTransferStatusChanged = "NVEasyFileTransferStatusChanged"
        
        /// 错误发生
        static let errorOccurred = "NVEasyErrorOccurred"
    }
    
    // MARK: - User Defaults Keys
    
    /// UserDefaults 键名常量
    enum UserDefaultsKeys {
        /// 最后连接的设备ID
        static let lastConnectedDeviceId = "NVEasyLastConnectedDeviceId"
        
        /// 音频设置
        static let audioSettings = "NVEasyAudioSettings"
        
        /// BLE设置
        static let bleSettings = "NVEasyBLESettings"
        
        /// 文件传输设置
        static let fileTransferSettings = "NVEasyFileTransferSettings"
    }
} 

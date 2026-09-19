import Flutter
import Foundation

/// Flutter事件流处理器
class NVEasyPluginStreamHandler: NSObject, FlutterStreamHandler {
    
    // MARK: - Singleton
    
    static let shared = NVEasyPluginStreamHandler()
    
    // MARK: - Properties
    
    private var eventSink: FlutterEventSink?
    private let eventQueue = DispatchQueue(label: "com.nveasy.events", qos: .userInitiated)
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - FlutterStreamHandler
    
    func onListen(
        withArguments arguments: Any?,
        eventSink: @escaping FlutterEventSink
    ) -> FlutterError? {
        NVEasyLogger.info("事件流监听已启动")
        self.eventSink = eventSink
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NVEasyLogger.info("事件流监听已取消")
        eventSink = nil
        return nil
    }
    
    // MARK: - Event Sending Methods
    
    /// 发送通用事件
    /// - Parameters:
    ///   - type: 事件类型
    ///   - data: 事件数据
    func sendEvent(type: NVEasyEventType, data: Any?) {
        eventQueue.async { [weak self] in
            guard let self = self, let eventSink = self.eventSink else {
                NVEasyLogger.warning("事件发送失败: eventSink 不可用")
                return
            }
            
            let eventData = EventData(type: type, data: data).toFlutterEvent()
            
            DispatchQueue.main.async {
                eventSink(eventData)
                NVEasyLogger.debug("事件已发送: \(type.rawValue)")
            }
        }
    }
    
    /// 发送设备状态
    /// - Parameters:
    ///   - state: 设备状态
    ///   - isConnected: 是否已连接
    func sendDeviceState(state: String, isConnected: Bool) {
        let stateData: [String: Any] = [
            "state": state,
            "isConnected": isConnected
        ]
        sendEvent(type: .deviceState, data: stateData)
    }
    
    /// 发送电池状态
    /// - Parameters:
    ///   - left: 左耳机电量
    ///   - right: 右耳机电量
    ///   - case: 充电仓电量
    func sendBatteryUpdate(left: UInt, right: UInt, caseBattery: UInt) {
        let batteryData: [String: Any] = [
            "left": left,
            "right": right,
            "caseBattery": caseBattery
        ]
        sendEvent(type: .batteryUpdate, data: batteryData)
    }
    
    /// 发送设备文件列表
    /// - Parameter files: 文件信息数组
    func sendDeviceFiles(_ files: [[String: Any]]) {
        sendEvent(type: .deviceFiles, data: files)
    }
    
    /// 发送转写状态
    /// - Parameter status: 转写状态信息
    func sendTranscribeStatus(_ status: [String: Any]) {
        sendEvent(type: .transcribeStatus, data: status)
    }
    
    /// 发送录音类型
    /// - Parameter mode: 转写状态信息
    func sendMeetingType(mode: Int) {
        let mode: [String: Any] = [
            "mode": mode
        ]
        sendEvent(type: .didUpdateMeetingType, data: mode)
    }
    
    /// 发送录音MP3文件路径
    /// - Parameters:
    ///   - mp3Path: MP3文件路径
    ///   - duration: 录音时长（秒）
    func sendRecordMP3FilePath(mp3Path: String, duration: Int) {
        let fileData: [String: Any] = [
            "mp3Path": mp3Path,
            "duration": duration
        ]
        sendEvent(type: .recordMP3File, data: fileData)
    }
    
    /// 发送错误信息
    /// - Parameter error: 错误信息
    func sendError(_ error: Error) {
        sendEvent(type: .error, data: error.localizedDescription)
    }
} 

import Foundation
import NVEasySDK

/// BLE命令响应处理器
/// 负责处理BLE命令响应和录音状态更新
class BLECommandHandler {
    
    // MARK: - Command Response Methods
    
    /// 处理命令响应
    /// - Parameters:
    ///   - manager: BLE管理器实例
    ///   - action: 命令动作
    ///   - isSuccess: 是否成功
    ///   - params: 响应参数
    func handleCommandResponse(manager: NVEasyBLEManager, action: String, isSuccess: Bool, params: [Any]?) {
        BLELogger.log("📡 [命令响应] 动作: \(action), 成功: \(isSuccess), 参数: \(params ?? [])")
        
        // 处理命令响应
        if let action = NVEasyAction(rawValue: action) {
            switch action {
            case .btName:
                BLELogger.log("📡 [命令响应] btName: \(params!.first! as! String)")
            case .bleName:
                BLELogger.log("📡 [命令响应] bleName: \(params!.first! as! String)")
            case .queryBtName:
                BLELogger.log("📡 [命令响应] queryBtName: \(params!.first! as! String)")
            case .queryBleName:
                BLELogger.log("📡 [命令响应] queryBleName: \(params!.first! as! String)")
            case .queryOffTime:
                BLELogger.log("📡 [命令响应] queryOffTime: \(params!.first! as! Int)")
            case .format:
                BLELogger.log("📡 [命令响应] format 成功: \(isSuccess), 格式化时不要对设备进行其他操作，App等待结果的超时时间建议为30s")
            case .micGain, .queryMicGain:
                BLELogger.log("📡 [命令响应] micGain: \(params!.first!), mic1增益: \(params![1] as! Int), mic2增益: \(params![2] as! Int)")
            default:
                BLELogger.log("📡 [命令响应] \(action) 成功: \(isSuccess) 参数: \(params ?? [])")
            }
        } else {
            BLELogger.log("📡 [命令响应] 未知动作: \(action) 成功: \(isSuccess) 参数: \(params ?? [])")
        }
    }
    
    /// 处理设备录音状态更新
    /// - Parameters:
    ///   - manager: BLE管理器实例
    ///   - action: 录音动作
    ///   - mode: 录音模式
    ///   - aiMode: AI模式
    func handleDeviceRecordStatusUpdate(manager: NVEasyBLEManager, action: NVEasyDevrecAction, mode: NVEasyRecordMode?, aiMode: NVEasyAIMode) {
        BLELogger.log("🎤 [设备录音] 动作: \(action), 模式: \(mode?.rawValue ?? -1), AI模式: \(aiMode)")
        
        if let mode = mode {
            // 发送会议类型到 Flutter 端
            NVEasyPluginStreamHandler.shared.sendMeetingType(mode: mode.rawValue)
            DeviceStatusDelegateManager.shared.recordMode = mode
            
            if action == .start {
                // 记录设备录音开始
                BLELogger.log("🎤 [设备录音] 开始录音，模式: \(mode.rawValue)")
            }
            
            BLERecordManager.shared.setMeetingMode(DeviceStatusDelegateManager.shared.isMeeting)
            // 会议模式单声道，通话时立体声
//            BLERecordManager.shared.isMono = isHuiyi
            
            // 打印模式信息
            let modeString = mode == NVEasyRecordMode.meeting ? "会议模式" : "通话模式"
            BLELogger.log("🎤 [设备录音] 设备模式更新: \(modeString) (rawValue: \(mode.rawValue))")
        }
        
        var status: Int = 0
        let isMeeting = mode == NVEasyRecordMode.meeting
        let modeValue = isMeeting ? 0 : 1
        let aiModeValue = 1
        var arguments: [String: Any?] = ["status": status, "mode": modeValue, "aiMode": aiModeValue]
        
        if action == .start {
            status = 1
            arguments["status"] = status
            BLELogger.log("🎤 [设备录音] 设备录音开始")
            
            // 设置录音开始时间
            BLEManager.shared.setRecordStartTime()
            
            NVEasyPlugin.methodChannel?.invokeMethod("didUpdateDeviceRecordStatus", arguments: arguments)
            NVEasyBLEManager.shared.startRecord(isMeetingMode: isMeeting)
        } else if action == .stop {
            BLELogger.log("🎤 [设备录音] 设备录音停止")
            
            // 记录录音停止时间
            let recordDuration = BLEManager.shared.getRecordDuration()
            BLELogger.log("🎤 [录音时间] 设备录音持续时间: \(BLEManager.shared.formatRecordDurationToString())")
            
            NVEasyPlugin.methodChannel?.invokeMethod("didUpdateDeviceRecordStatus", arguments: arguments)
            NVEasyBLEManager.shared.stopRecord(isMeetingMode: isMeeting)
            NVEasyBLEManager.shared.getFileList()
        }
    }
    
    /// 处理配对角色信息
    /// - Parameters:
    ///   - manager: BLE管理器实例
    ///   - role: 配对角色
    ///   - sn: 序列号
    ///   - labelSN: 标签序列号
    ///   - wifiMac: WiFi MAC地址
    ///   - leftMAC: 左耳MAC地址
    ///   - rightMAC: 右耳MAC地址
    ///   - caseMAC: 充电盒MAC地址
    func handlePairRole(manager: NVEasyBLEManager, role: NVEasyPairRole, sn: String, labelSN: String, wifiMac: String?, leftMAC: String, rightMAC: String, caseMAC: String) {
        BLELogger.log("🔗 [配对角色] 角色: \(role), 序列号: \(sn), 标签序列号: \(labelSN), WiFi MAC: \(wifiMac ?? "")")
        BLELogger.log("🔗 [配对角色] 左耳MAC: \(leftMAC), 右耳MAC: \(rightMAC), 盒子MAC: \(caseMAC)")
    }
    
    /// 处理认证序列号
    /// - Parameters:
    ///   - manager: BLE管理器实例
    ///   - sn: 序列号
    ///   - bleMac: 蓝牙MAC地址
    ///   - wifiMac: WiFi MAC地址
    ///   - labelSN: 标签序列号
    func handleAuthsn(manager: NVEasyBLEManager, sn: String, bleMac: String, wifiMac: String, labelSN: String?) {
        BLELogger.log("🔐 [认证序列号] 序列号: \(sn), 蓝牙MAC: \(bleMac), WiFi MAC: \(wifiMac), 标签序列号: \(labelSN ?? "")")
    }
}

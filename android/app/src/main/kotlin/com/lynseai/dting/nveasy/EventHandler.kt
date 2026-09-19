package com.lynseai.dting.nveasy

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * EventHandler 类负责管理和发送事件到 Flutter 端
 * 包括设备状态、录音数据、电池信息等事件的处理
 * 支持两种事件发送方式：EventChannel（事件流）和 MethodChannel（方法调用）
 */
class EventHandler(private val methodChannel: MethodChannel) {
    // 事件接收器，用于向 Flutter 发送事件流
    private var eventSink: EventChannel.EventSink? = null

    /**
     * 事件类型枚举
     * 定义了所有支持的事件类型
     */
    enum class NvEasyEventType(val value: String) {
        DEVICE_STATE("deviceState"),      // 设备状态
        BATTERY_UPDATE("batteryUpdate"),  // 电池状态更新
        DEVICE_FILES("deviceFiles"),      // 设备文件列表
        TRANSCRIBE_STATUS("transcribeStatus"), // 转写状态
        DID_UPDATE_MEETING_TYPE("didUpdateMeetingType"), // 设备模式变换
        ERROR("error")                    // 错误信息
    }

    /**
     * 设置事件接收器
     */
    fun setEventSink(sink: EventChannel.EventSink?) {
        this.eventSink = sink
    }

    /**
     * 清除事件接收器
     */
    fun clearEventSink() {
        eventSink = null
    }

    /**
     * 发送事件的通用方法
     * @param type 事件类型
     * @param data 事件数据
     */
    private fun sendEvent(type: NvEasyEventType, data: Any?) {
        val eventData = mapOf(
            "type" to type.value,
            "data" to (data ?: null)
        )
        eventSink?.success(eventData)
    }

    /**
     * 发送设备状态更新
     * @param state 设备状态
     * @param isConnected 连接状态
     */
    fun sendDeviceState(state: String, isConnected: Boolean) {
        val stateData = mapOf(
            "state" to state,
            "isConnected" to isConnected
        )
        sendEvent(NvEasyEventType.DEVICE_STATE, stateData)
    }

    /**
     * 发送电池状态更新
     * @param left 左耳机电量
     * @param right 右耳机电量
     * @param caseBattery 充电盒电量
     */
    fun sendBatteryUpdate(left: Int, right: Int, caseBattery: Int) {
        val batteryData = mapOf(
            "left" to left,
            "right" to right,
            "caseBattery" to caseBattery
        )
        sendEvent(NvEasyEventType.BATTERY_UPDATE, batteryData)

        // 通过 MethodChannel 发送电池更新（保持兼容性）
        val dictionary = mapOf("left" to left, "right" to right, "caseBattery" to caseBattery)
        methodChannel.invokeMethod("didUpdateBattery", dictionary)
    }

    /**
     * 发送错误信息
     * @param error 错误信息
     */
    fun sendError(error: String) {
        sendEvent(NvEasyEventType.ERROR, error)
    }

    /**
     * 发送设备发现事件
     * @param mac 设备 MAC 地址
     * @param name 设备名称
     */
    fun sendDeviceDiscovered(mac: String, name: String) {
        val dictionary = mapOf("uuid" to mac, "name" to name)
        methodChannel.invokeMethod("didDiscover", dictionary)
    }

    /**
     * 发送设备连接事件
     * @param mac 设备 MAC 地址
     * @param name 设备名称
     */
    fun sendDeviceConnected(mac: String, name: String) {
        val dictionary = mapOf("uuid" to mac, "name" to name)
        methodChannel.invokeMethod("didConnect", dictionary)
    }
 
     /**
     * 发送设备连接失败事件 
     * @param mac 设备 MAC 地址
     */
    fun sendDeviceFailConnected(mac: String, linkstatus: Int) {
        val dictionary = mapOf("uuid" to mac, "linkstatus" to linkstatus)
        methodChannel.invokeMethod("didFailConnect", dictionary)
    }
    /**
     * 发送设备断开连接事件
     * @param mac 设备 MAC 地址
     * @param name 设备名称
     */
    fun sendDeviceDisconnected(mac: String, name: String) {
        val dictionary = mapOf("uuid" to mac, "name" to name)
        methodChannel.invokeMethod("didDisconnect", dictionary)
    }

    /**
     * 发送绑定状态更新事件
     * @param isBound 是否已绑定
     * @param isSuccess 操作是否成功
     */
    fun sendBindStatusUpdate(isBound: Boolean, isSuccess: Boolean) {
        val dictionary = mapOf("isBound" to isBound, "isSuccess" to isSuccess)
        methodChannel.invokeMethod("didUpdateBound", dictionary)
    }

    /**
     * 发送认证 SN 接收事件
     * @param authSN 认证序列号
     * @param bleMac 蓝牙 MAC 地址
     * @param wifiMac WiFi MAC 地址
     */
    fun sendAuthSNReceived(authSN: String, bleMac: String, wifiMac: String) {
        val dictionary = mapOf("sn" to authSN, "bleMac" to bleMac, "wifiMac" to wifiMac)
        methodChannel.invokeMethod("didReceiveAuthsn", dictionary)
    }

    /**
     * 发送文件列表接收事件
     * @param fileList 文件列表
     */
    fun sendFileListReceived(fileList: List<Map<String, Any>>) {
        methodChannel.invokeMethod("didReceiveFiles", fileList)
    }

    /**
     * 发送录音类型 mode 0 是会议模式 1是通话模式
     */
    fun sendMeetingType(mode: Int) {
        val modeData = mapOf("mode" to mode)
        
        // 通过 EventChannel 发送事件
        sendEvent(NvEasyEventType.DID_UPDATE_MEETING_TYPE, modeData)
        
        // 通过 MethodChannel 发送事件（保持兼容性）
        methodChannel.invokeMethod("didUpdateMeetingType", modeData)
    }

    /**
     * onDeviceRecord, status = 1, mode = 1, aiMode = 2, mRecording = false 已经开始录音 mode 1是通话录音 0是会议录音
     *  onDeviceRecord, status = 0, mode = 1, aiMode = 2, mRecording = true 停止录音
     */
    fun sendDeviceRecordStatus(status: Int, mode: Int, aiMode: Int) {
        val status = mapOf("status" to status, "mode" to mode, "aiMode" to aiMode)
        methodChannel.invokeMethod("didUpdateDeviceRecordStatus", status)
    }

    /**
     * 用来控制首页是否展示那个录音的状态，不做数据上传和逻辑处理
     */
    fun sendRecordStatus(status: Int, mode: Int) {
        val status = mapOf("status" to status, "mode" to mode)
        methodChannel.invokeMethod("sendRecordStatus", status)
    }

    /**
     * 返回录音的mp3文件地址
     */
    fun sendRecordMP3FilePath(fileMp3Path: String, fileDuration: Int, scene: Int, recordStartTime: String) {
        val params = mapOf(
            "fileMp3Path" to fileMp3Path,
            "fileDuration" to fileDuration,
            "scene" to scene,
            "recordStartTime" to recordStartTime,
        )
        methodChannel.invokeMethod("didReceiveRecordMP3FilePath", params)
    }

    /**
     * 返回录音的mp3文件地址
     */
//    fun sendRecordMP3FilePathAndEndTime(fileMp3Path: String, endTime: Long) {
//        val params = mapOf(
//            "fileMp3Path" to fileMp3Path,
//            "endTime" to endTime
//        )
//        methodChannel.invokeMethod("didRecordMP3FilePathAndEndTime", params)
//    }

    /**
     * 录音文件的下载进度
     */
    fun sendDownloadFileProgress(currentPacket: Int, totalPacket: Int,currentNumber: Int) {
        val progress = mapOf("currentPacket" to currentPacket, "totalPacket" to totalPacket, "currentNumber" to currentNumber)
        methodChannel.invokeMethod("didUpdateDownloadFileProgress", progress)
    }

    /**
     * 设备ota升级过程和状态
     * status = 0, 升级开始 status = 1, 升级中 status = 2, 升级成功，status = 3, 升级失败
     * progress = 0~100
     * upgradedSize = 升级大小
     * error = 错误信息
     *
     * "为保证升级成功，请断开经典蓝牙\n正在升级，请等待...\n已完成："
     *                             + progress + "%, 已发送" + upgradedSize + "个字节"
     *                             + "\n传输速率：" + upgradedSize / currentTime + "KB/s" +
     *                             (progress == 100 ? "\n正在更新固件，预计10几秒..." : ""
     */
    fun sendDeviceUpdateOtaStatus(status: Int, progress: Int, upgradedSize: Int, error: String) {
        val map = mapOf(
            "status" to status,
            "progress" to progress,
            "upgradedSize" to upgradedSize,
            "error" to error
        )
        methodChannel.invokeMethod("deviceUpdateOtaStatus", map)
    }

    /**
     * 发送设备版本信息
     */
    fun sendDeviceVersion(softwareVersion: String, hardwareVersion: String) {
        val map = mapOf(
            "softwareVersion" to softwareVersion,
            "hardwareVersion" to hardwareVersion
        )
        methodChannel.invokeMethod("deviceVersion", map)
    }

    /**
     * 发送WiFi状态
     *  OPENING,
     *  OPENED,
     *  CONNECTING,
     *  CONNECTED,
     *  STOPPING,
     *  STOPPED;
     */
    fun sendWifiStatus(wifiStatus: Int) {
        val map = mapOf("wifiStatus" to wifiStatus)
        methodChannel.invokeMethod("deviceWifiStatus", map)
    }

    /**
     * 获取下载文件速度
     */
    fun sendFileDownloadSpeed(speedKbps: Int) {
        val map = mapOf("speedKbps" to speedKbps)
        methodChannel.invokeMethod("fileDownloadSpeed", map)
    }

    /**
     * 下载所有文件状态
     */
    fun sendDownloadAllFileUI(downFileStatus: Int) {
        val map = mapOf("downFileStatus" to downFileStatus)
        methodChannel.invokeMethod("sendDownloadAllFileUI", map)
    }

    //status 做成枚举对象
    enum class OtaUpdateStatus(val value: Int) {
        STARTED(0),
        PROGRESS(1),
        SUCCESS(2),
        FAILED(3)
    }


}
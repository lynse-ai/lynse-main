package com.lynseai.dting.nveasy

import android.app.Activity
import android.app.Application
import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * NvEasyPlugin 是 Flutter 插件的主入口类
 * 负责处理与 Flutter 端的通信，包括方法调用和事件流
 * 实现了 FlutterPlugin 用于插件生命周期管理
 * 实现了 MethodCallHandler 用于处理来自 Flutter 的方法调用
 * 实现了 StreamHandler 用于处理事件流通信
 */
class NvEasyPlugin(private val application: Application, context1: Activity) : FlutterPlugin,
    MethodCallHandler, StreamHandler {
    // Flutter 方法通道，用于处理同步方法调用
    private lateinit var methodChannel: MethodChannel

    // Flutter 事件通道，用于处理异步事件流
    private lateinit var eventChannel: EventChannel

    // 事件处理器，用于管理和发送事件
    private lateinit var eventHandler: EventHandler

    // 音频工具类，处理音频相关功能
    private lateinit var audioUtils: AudioUtils

    // 蓝牙管理器，处理蓝牙相关功能
    private lateinit var bleManager: BleManager

    // 应用上下文
    private lateinit var context: Context

    private var contextTemp: Activity = context1

    private val TAG = "NvEasyPlugin"

    /**
     * 插件附加到 Flutter 引擎时调用
     * 初始化通道和各个功能模块
     */
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        methodChannel =
            MethodChannel(flutterPluginBinding.binaryMessenger, "nv_easy_plugin/methods")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "nv_easy_plugin/events")
        eventChannel.setStreamHandler(this)

        // 初始化工具类
        eventHandler = EventHandler(methodChannel)
        audioUtils = AudioUtils(flutterPluginBinding.applicationContext)
        bleManager = BleManager(application, eventHandler, audioUtils)
    }

    /**
     * 处理来自 Flutter 的方法调用
     * 包括设备管理、录音控制、设备信息查询等功能
     */
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // 获取平台版本信息
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            // 初始化 Opus 解码器
            "initOpus" -> {
                val mono = call.argument<Boolean>("mono")
                if (mono == null) {
                    result.error("invalid_argument", "mono parameter is required", null)
                    return
                }
                audioUtils.initOpus(mono)
                result.success("initOpus!")
            }
            // 开始扫描蓝牙设备
            "startScan" -> {
                bleManager.startScan()
                result.success("startScan!")
            }
            // 停止扫描蓝牙设备
            "stopScan" -> {
                bleManager.stopScan()
                result.success(null)
            }
            // 连接蓝牙设备
            "startConnect" -> {
                val uuid = call.argument<String>("uuid")
                if (uuid == null) {
                    result.error("invalid_argument", "UUID is required", null)
                    return
                }
                val success = bleManager.connect(uuid)
                if (success) {
                    result.success("startConnect!")
                } else {
                    result.error("device_not_found", "Device not found", null)
                }
            }
            // 断开蓝牙设备连接
            "startDisconnect" -> {
                val uuid = call.argument<String>("uuid")
                if (uuid == null) {
                    result.error("invalid_argument", "UUID is required", null)
                    return
                }
                val success = bleManager.disconnect(uuid)
                if (success) {
                    result.success("startDisconnect!")
                } else {
                    result.error("device_not_found", "Device not found", null)
                }
            }
            // 开始录音
            "startRecord" -> {
                bleManager.startRecord()
                result.success("startRecord!")
            }
            // 暂停录音
            "pauseRecord" -> {
                result.success("pauseRecord!")
            }
            // 恢复录音
            "resumeRecord" -> {
                result.success("resumeRecord!")
            }
            // 停止录音
            "stopRecord" -> {
                val fileInfo = bleManager.stopRecord()
                result.success(fileInfo)
            }
            // 重置设备
            "resetDevice" -> {
                bleManager.resetDevice()
                result.success("resetDevice!")
            }
            // 查询设备版本
            "queryVersion" -> {
                bleManager.queryVersion()
                result.success("queryVersion!")
            }
            // 查询设备序列号
            "querySN" -> {
                bleManager.querySN()
                result.success("querySN!")
            }
            // 设置设备名称
            "setName" -> {
                val name = call.argument<String>("name")
                if (name == null) {
                    result.error("invalid_argument", "Name is required", null)
                    return
                }

                if (name.length > 16) {
                    result.error("invalid_argument", "Name is too long", null)
                    return
                }
                bleManager.setName(name)
                result.success("setName!")
            }
            // 获取电池电量
            "getBattery" -> {
                bleManager.getBattery()
                result.success("getBattery!")
            }
            // 设置自动关机时间
            "offtime" -> {
                val minutes = call.argument<Int>("minutes")
                if (minutes == null) {
                    result.error("invalid_argument", "Minutes is required", null)
                    return
                }
                bleManager.setOffTime(minutes)
                result.success("offtime!")
            }
            // 获取设备绑定状态
            "getBindStatus" -> {
                val isBind = bleManager.getBindStatus()
                result.success(isBind)
            }
            // 绑定/解绑设备
            "bindDevice" -> {
                val isBind = call.argument<Boolean>("isBind")
                if (isBind == null) {
                    result.error("invalid_argument", "isBind is required", null)
                    return
                }
                bleManager.bindDevice(isBind)
                result.success("bindDevice!")
            }
            // 获取设备文件列表
            "getFileList" -> {
                bleManager.getFileList()
                result.success("getFileList!")
            }
            // 下载设备文件
            "downloadFile" -> {
                val fileSN = call.argument<Int>("sn")
                if (fileSN == null) {
                    result.error("invalid_argument", "File SN is required", null)
                    return
                }
                bleManager.downloadFile(fileSN)
                result.success("downloadFile!")
            }
            // 下载设备文件通过wifi快传的方式
            "downloadFileOfWifi" -> {
                Log.d(TAG, "downloadFileOfWifi")
                val fileSN = call.argument<Int>("sn")
                if (fileSN == null) {
                    result.error("invalid_argument", "File SN is required", null)
                    return
                }
                bleManager.downloadFileOfWifi(fileSN)
                result.success("downloadFileOfWifi!")
            }
            //OTA升级
            "deviceOta" -> {
                val filePath = call.argument<String>("otaFilePath")
                //新的版本号
                val version = call.argument<String>("newVersion")
                if (filePath == null) {
                    result.error("invalid_argument", "OTa File path is required", null)
                    return
                }
                if (version == null) {
                    result.error("invalid_argument", "New Version is required", null)
                    return
                }
                bleManager.deviceUpdateOta(filePath, version)
                result.success("deviceOta!")
            }
            // 最小化应用到后台
            "minimizeApp" -> {
                try {
                    val activity = contextTemp
                    activity.moveTaskToBack(true)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("minimize_failed", "Failed to minimize app: ${e.message}", null)
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * 插件从 Flutter 引擎分离时调用
     * 清理资源和监听器
     */
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    /**
     * 设置事件流监听器
     */
    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        eventHandler.setEventSink(sink)
    }

    /**
     * 取消事件流监听器
     */
    override fun onCancel(arguments: Any?) {
        eventHandler.clearEventSink()
    }
}

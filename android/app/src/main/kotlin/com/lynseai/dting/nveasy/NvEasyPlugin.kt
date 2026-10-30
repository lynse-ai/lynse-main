package com.lynseai.dting.nveasy

import android.app.Activity
import android.app.Application
import android.content.Context
import android.util.Log
import com.lynseai.dting.TransferForegroundService
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

    // 蓝牙管理器，处理蓝牙相关功能。
    // SDK 路径下只保留插件注册以复用前台保活；厂商 BleManager 必须惰性构造，
    // 否则它会在 onAttachedToEngine 时就初始化厂商 BLE，跟统一 SDK 抢同一个适配器。
    private val bleManager: BleManager by lazy {
        BleManager(application, eventHandler, audioUtils)
    }

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
                // 厂商 v1.2.0 起 init 必须带 appKey，鉴权不过设备对任何命令都沉默。
                // AppKey 由上层在连接时给（设置页存的 neview_appKey），这里补一次 init。
                val appKey = call.argument<String>("appKey")
                if (!appKey.isNullOrBlank()) {
                    bleManager.applyAppKey(application, appKey)
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
            // 暂停录音：真机验证 record(dev,2,mode) → onRecordExtended status=2
            "pauseRecord" -> {
                bleManager.pauseRecord()
                result.success("pauseRecord!")
            }
            // 恢复录音：真机验证 record(dev,3,mode) → onRecordExtended status=3
            "resumeRecord" -> {
                bleManager.resumeRecord()
                result.success("resumeRecord!")
            }
            // 打点：真机验证 recordMark → onRecordMark status=0 + index/offset
            "addMark" -> {
                bleManager.addMark()
                result.success("addMark!")
            }
            // 取消下载：stopDownloadFiles（厂商口径——它不会顺手关 WiFi）
            "cancelDownload" -> {
                bleManager.cancelDownload()
                result.success("cancelDownload!")
            }
            // 删除设备文件：通道已接通，但**未真机验证**（不可逆），上层能力声明仍不给
            "deleteFile" -> {
                val sn = call.argument<Int>("sn")
                if (sn == null) {
                    result.error("invalid_argument", "File SN is required", null)
                    return
                }
                bleManager.deleteFile(sn, call.argument<String>("name"))
                result.success("deleteFile!")
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
            // 传输保活：起前台服务（文件下载/快传/固件升级开始时调）
            "startTransferGuard" -> {
                val label = call.argument<String>("label") ?: "正在与录音卡同步文件"
                TransferForegroundService.start(context, label)
                result.success(true)
            }
            // 传输保活：收前台服务（传输结束/失败/取消时必须调）
            "stopTransferGuard" -> {
                TransferForegroundService.stop(context)
                result.success(true)
            }

            // ── 厂商 AAR 接口扫档（NewviewVendorProbe）──────────────────
            // 参考实现裁判：所有 *APP# 命令都由厂商 SDK 发出，含它自带的
            // appkey/sdkkey 握手。用来判定「卡的某接口到底活没活」，
            // 而不是判定「我们的裸协议对不对」。
            "vendorProbeStart" -> {
                val name = call.argument<String>("name")
                val appKey = call.argument<String>("appKey")
                val rec = call.argument<Boolean>("record") ?: true
                val wifi = call.argument<Boolean>("wifi") ?: false
                val del = call.argument<Boolean>("delete") ?: false
                val mac = call.argument<String>("mac")
                val advHex = call.argument<String>("advHex")
                result.success(
                    NewviewVendorProbe.start(
                        application, name, appKey, rec, wifi, del, mac, advHex
                    )
                )
            }
            "vendorProbeRunning" -> result.success(NewviewVendorProbe.isRunning)
            "vendorProbeTail" -> {
                val n = call.argument<Int>("lines") ?: 400
                result.success(NewviewVendorProbe.tail(n))
            }
            "vendorProbeStop" -> {
                NewviewVendorProbe.stop()
                result.success(true)
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

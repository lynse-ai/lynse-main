package com.lynseai.dting.nveasy

import android.app.Application
import android.bluetooth.BluetoothGatt
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.lynseai.dting.utils.LogUtils
import com.lynseai.dting.utils.MMKVUtils
import com.nveasy.audio.Constants
import com.nveasy.ble.NvEasyBleManager
import com.nveasy.ble.callback.NvEasyBleCallback
import com.nveasy.ble.callback.NvEasyBleConnectCallback
import com.nveasy.ble.callback.NvEasyBleFilesCallback
import com.nveasy.ble.callback.NvEasyBleScanCallback
import com.nveasy.ble.data.ErrorType
import com.nveasy.ble.data.NvEasyBleDevice
import com.nveasy.ble.data.NvEasyDownloadFile
import com.nveasy.ble.data.NvEasyFile
import com.nveasy.ble.exception.BleException
import com.nveasy.ble.exception.FilesReceiverException
import java.io.FileOutputStream

/**
 * BleManager 类负责管理蓝牙设备的连接、通信和文件传输
 * 包括设备扫描、连接管理、录音控制、文件下载等功能
 */
class BleManager(
    private val application: Application,
    val eventHandler: EventHandler,
    val audioUtils: AudioUtils
) {
    val TAG = "断点续传"

    // NvEasy 蓝牙管理器实例
    val nvEasyBleManager: NvEasyBleManager = NvEasyBleManager.getInstance()

    // 已发现设备的缓存，键为设备 MAC 地址
    private val devices = mutableMapOf<String, NvEasyBleDevice>()

    // 当前连接的设备
    var currentDevice: NvEasyBleDevice? = null

    // 设备文件列表缓存
    var nvEasyFiles: ArrayList<NvEasyFile> = ArrayList()

    //  下载文件缓存
    val mDownloadFiles: ArrayList<NvEasyDownloadFile> = ArrayList<NvEasyDownloadFile>()

    var mDeviceType: Int = -1

    //录音类型
    var mRecordType: Int = 0

    var mDownloadFileStream: FileOutputStream? = null

    var opusDownFilePath: String = ""

    var CHANNELS: Constants.Channels = Constants.Channels.mono

    //是否采用wifi快传
    var mFileWifiEnable = false

    //是否要下载最后录音文件
    var isLastRecord: Boolean = false

    var currentNumber: Int = 0

    //录音开始时间
    var mStartRecordTime = 0L

    //录音结束时间
    var mEndRecordTime = 0L


    // 断点续传信息
    var mBPResumeSN = 0 // 断点续传文件序列号
    var mBPResumeOffset = 0 // 断点续传偏移量（已下载的字节数）
    var mBPResumeName: String? = null // 断点续传文件名
    var mBPResumeFilePath: String? = null // 断点续传文件路径
    var mBpResumeDeviceMac: String? = null // 断点续传设备MAC


    init {
        // 初始化蓝牙管理器
        nvEasyBleManager.init(application)
        //初始化文件存储
        MMKVUtils.initialize(application)
        // 获取断点续传信息
        getResumeDataOffset()
        LogUtils.getInstance().initialize(application)
        Log.d("DTingChannel", "BleManager init")
    }

    /**
     * 开始扫描蓝牙设备
     */
    fun startScan() {
        nvEasyBleManager.scan(1000000, mScanCallback)
        Log.d("DTingChannel", "BleManager startScan mScanCallback = ${mScanCallback}")
        LogUtils.getInstance().d("DTingChannel", "BleManager startScan")
    }

    /**
     * 停止扫描蓝牙设备
     */
    fun stopScan() {
        Log.d("DTingChannel", "BleManager stopScan")
        nvEasyBleManager.stopScan()
        LogUtils.getInstance().d("DTingChannel", "BleManager stopScan")
    }

    /**
     * 连接指定的蓝牙设备
     * @param uuid 设备 MAC 地址
     * @return 是否成功发起连接
     */
    fun connect(uuid: String): Boolean {
        val device = devices[uuid] ?: return false
        nvEasyBleManager.connect(device, mConnectCallback, mBleCallback)
        LogUtils.getInstance().d("DTingChannel", "BleManager connect")
        return true
    }

    /**
     * 断开指定设备的连接
     * @param uuid 设备 MAC 地址
     * @return 是否成功断开连接
     */
    fun disconnect(uuid: String): Boolean {
        val device = devices[uuid] ?: return false
        nvEasyBleManager.disconnect(device)
        LogUtils.getInstance().d("DTingChannel", "BleManager disconnect")
        return true
    }

    /**
     * 开始录音
     * 创建录音文件并启动设备录音
     */
    fun startRecord() {
        handleStartRecord()
    }


    /**
     * 停止录音
     * 停止设备录音并关闭文件
     * @return 包含录音文件信息的Map，包括pcmPath和mp3Path
     */
    fun stopRecord(): Map<String, String>? {
        return handleStopRecord()
    }

    /**
     * 重置设备到出厂设置
     */
    fun resetDevice() {
        nvEasyBleManager.factoryMode(currentDevice)
    }

    /**
     * 查询设备版本信息
     */
    fun queryVersion() {
        nvEasyBleManager.queryVersion(currentDevice)
    }

    /**
     * 查询设备序列号
     */
    fun querySN() {
        nvEasyBleManager.queryAuthSN(currentDevice)
    }

    /**
     * 设置设备名称
     * @param name 新的设备名称
     */
    fun setName(name: String) {
        nvEasyBleManager.setBleName(currentDevice, name)
        nvEasyBleManager.setBluetoothName(currentDevice, name)
    }

    /**
     * 获取设备电池电量
     */
    fun getBattery() {
        nvEasyBleManager.queryBattery(currentDevice)
    }

    /**
     * 设置设备自动关机时间
     * @param minutes 自动关机时间（分钟）
     */
    fun setOffTime(minutes: Int) {
        nvEasyBleManager.setOffTime(currentDevice, minutes)
    }

    /**
     * 获取设备绑定状态
     * @return 是否已绑定
     */
    fun getBindStatus(): Boolean {
        return currentDevice?.hasState(NvEasyBleDevice.STATE_BOUND.toInt()) ?: false
    }

    /**
     * 绑定或解绑设备
     * @param isBind true 表示绑定，false 表示解绑
     */
    fun bindDevice(isBind: Boolean) {
        nvEasyBleManager.boundDevice(currentDevice, isBind)
    }

    /**
     * 获取设备文件列表
     */
    fun getFileList() {
        nvEasyBleManager.stopDownloadFiles(currentDevice)
        Log.d("DTingChannel", "开始获取设备文件列表")
        Handler(Looper.getMainLooper()).postDelayed({
            nvEasyBleManager.getFilesList(currentDevice)
        }, 3000)
    }

    /**
     * 下载指定的设备文件
     * @param fileSN 文件序列号
     */
    fun downloadFile(fileSN: Int) {
        handleDownloadFile(fileSN)
    }

    /**
     * 下载文件，通过wifi快传的方式
     */
    fun downloadFileOfWifi(fileSN: Int) {
        Log.d("DTingChannel", "开始WiFi快传下载文件: $fileSN")

        if (currentDevice == null) {
            Log.e("DTingChannel", "WiFi快传失败：设备未连接")
            return
        }

        // 设置WiFi快传状态
        mFileWifiEnable = true
        nvEasyBleManager.switchWifi(currentDevice, true, true)
        try {
            if (mDownloadFileStream != null) {
                mDownloadFileStream?.close()
                mDownloadFileStream = null
            }
        } catch (e: Exception) {
            Log.e("DTingChannel", "清理下载流失败: ${e.message}")
        }

        // 开启WiFi热点
        Log.d("DTingChannel", "开启WiFi热点进行快传")
        nvEasyBleManager.switchWifi(currentDevice, true, true)

        // 准备下载文件列表（等待WiFi连接成功后开始下载）
        handleDownloadFile(fileSN, true)
    }

    /**
     * 设备的ota升级
     */
    fun deviceUpdateOta(filePath: String, version: String) {
        Log.d("DTingChannel", "开始升级设备, 文件路径: $filePath, 版本: $version")
        handleDeviceUpdateOta(filePath, version)
    }

    /**
     * 蓝牙扫描回调
     * 处理设备扫描过程中的各种事件
     */
    private val mScanCallback: NvEasyBleScanCallback = object : NvEasyBleScanCallback {
        override fun onScanStarted(success: Boolean) {
            // 开始扫描回调
            Log.e("DTingChannel", "开始扫描")
        }

        override fun onScanFinished(scanResultList: List<NvEasyBleDevice>) {
            // 扫描完成回调
            Log.e("DTingChannel", "扫描完成")
        }

        override fun onScanning(bleDevice: NvEasyBleDevice) {
            Log.e("DTingChannel", "onScanning = bleDevice = ${bleDevice.name} ${bleDevice.mac}")
            // 发现设备回调
            devices[bleDevice.mac] = bleDevice
            eventHandler.sendDeviceDiscovered(bleDevice.mac, bleDevice.name)
        }
    }

    /**
     * 蓝牙连接回调
     * 处理设备连接过程中的各种事件
     */
    private val mConnectCallback: NvEasyBleConnectCallback = object : NvEasyBleConnectCallback {
        override fun onStartConnect(bleDevice: NvEasyBleDevice) {
            Log.d("DTingChannel", "开始连接")
        }

        override fun onConnectFail(bleDevice: NvEasyBleDevice, exception: BleException) {
            Log.d("DTingChannel", "连接失败")
            eventHandler.sendDeviceFailConnected(bleDevice.mac, 1)
        }

        override fun onConnectSuccess(
            bleDevice: NvEasyBleDevice,
            gatt: BluetoothGatt,
            status: Int
        ) {
            currentDevice = bleDevice
            mBpResumeDeviceMac = bleDevice.mac
            nvEasyBleManager.setFilesCallback(bleDevice, mFilesCallback)
            eventHandler.sendDeviceConnected(bleDevice.mac, bleDevice.name)
        }

        override fun onDisConnected(
            isActiveDisConnected: Boolean,
            device: NvEasyBleDevice,
            gatt: BluetoothGatt,
            status: Int
        ) {
            currentDevice = null
            eventHandler.sendDeviceDisconnected(device.mac, device.name)
        }
    }

    /**
     * 蓝牙通信回调
     * 处理设备通信过程中的各种事件
     */
    private val mBleCallback: NvEasyBleCallback = object : NvEasyBleCallback() {
        override fun onBlePrepared() {
            // 设备准备就绪
            Log.d("DTingChannel", "准备就绪了")
            if (getDeviceType() == NvEasyBleDevice.AI_NOTES) {
                Log.d("DTingChannel", "准备就绪了，获取录音模式")
                nvEasyBleManager?.querySwitch(currentDevice)
            }
        }

        override fun onBleFailed(errorType: ErrorType) {
            // 设备出错信息
        }

        override fun onCommandFailed(command: String) {
            // 命令执行失败
        }

        override fun onUpdateBattery(left: Int, right: Int, batteryHouse: Int) {
            // 电池电量更新
            eventHandler.sendBatteryUpdate(left, right, batteryHouse)
        }

        override fun onQueryVersion(softwareVersion: String, hardwareVersion: String) {
            // 版本信息查询结果
            Log.d(
                "DTingChannel",
                "onQueryVersion: softwareVersion= $softwareVersion, hardwareVersion = $hardwareVersion"
            )
            eventHandler.sendDeviceVersion(softwareVersion, hardwareVersion)
        }

        override fun onSetVolume(volume: Int) {
            // 音量设置结果
        }

        override fun onPlay(status: Int) {
            // 播放状态变化
        }

        override fun onANC(mode: Int) {
            // 降噪模式变化
        }

        override fun onEQ(eqMode: Int) {
            // EQ 模式变化
        }

        override fun onButton(leftBtnFun: Int, rightBtnFun: Int) {
            // 按键功能变化
        }

        override fun onFactory(status: Boolean) {
            // 恢复出厂设置结果
        }

        override fun onDeviceRecord(status: Int, mode: Int, aiMode: Int) {
            // 设备录音状态变化
            //onDeviceRecord, status = 1, mode = 1, aiMode = 2, mRecording = false 已经开始录音
            //onDeviceRecord, status = 0, mode = 1, aiMode = 2, mRecording = true 停止录音
            //mode = 0会议录音，mode = 1 是通话录音
            //按键和通话终端拾音上报
            mRecordType = mode
            Log.d(
                "DTingChannel",
                "onDeviceRecord, status = $status, mode = $mode, aiMode = $aiMode"
            )
            eventHandler.sendDeviceRecordStatus(status, mode, aiMode)
        }

        override fun onRecord(
            status: Int,
            mode: Int,
            sampleRate: Int,
            channel: Int,
            recordMode: Int,
            recordTime: Int
        ) {
            // 录音参数变化
            Log.d("DTingChannel", "onRecord, status = $status, mode = $mode")
            eventHandler.sendRecordStatus(status, mode)
        }

        override fun onStream(data: ByteArray, frameLen: Int, totalLen: Int) {
            // 录音数据流回调
            Log.d(
                "DTingChannel",
                "录音数据上报 - frameLen: $frameLen, totalLen: $totalLen, data size: ${data.size}"
            )
            handleOnStream(data, frameLen, totalLen)
        }

        override fun onCall(status: Int, callNumber: String) {
            // 通话状态变化
        }

        override fun onSwitch(mode: Int) {
            // 模式切换
            val modeString = if (mode == 0) "会议模式" else "通话模式"
            Log.d("DTingChannel", "设备模式更新 - 状态: $mode ($modeString)")

            // 更新本地模式变量
            mRecordType = mode

            // 发送到Flutter
            eventHandler.sendMeetingType(mode)
        }

        override fun onEDR(status: Int, btMac: String, btName: String) {
            // EDR 状态变化
        }

        override fun onDeviceStorage(freeSpace: Long, totalSpace: Long) {
            // 设备存储空间信息
        }

        override fun onFormatStorage(status: Boolean, freeSpace: Long, totalSpace: Long) {
            // 格式化存储结果
        }

        override fun onBound(status: Boolean, isBound: Boolean) {
            Log.d("DTingChannel", "绑定状态status: ${status} isBound: $isBound")
            // 绑定状态变化
            eventHandler.sendBindStatusUpdate(isBound, status)
        }


        override fun onAuthSN(authSN: String, bleMac: String, wifiMac: String, labelSN: String) {
            //labelSN需要mBleDevice.getProtocolVersion() >= NvEasyBleDevice.PROTOCOL_VERSION_19才有数据
            eventHandler.sendAuthSNReceived(authSN, bleMac, wifiMac)
        }

        override fun onBluetoothName(status: Boolean, bluetoothName: String) {
            // 蓝牙名称设置结果
        }

        override fun onBleName(status: Boolean, bleName: String) {
            // BLE 名称设置结果
        }

        override fun onOffTime(status: Boolean, offTime: Int) {
            // 自动关机时间设置结果
        }

        /**
         * Log.i(TAG,"onOffTime, status = " + status + ", mode = " + mode +  ", mic1Gain = " + mic1Gain +  ", mic2Gain = " + mic2Gain);
         *   showMoreFunctionsText("设置/查询麦克增益"+ (status ? "成功" : "失败") + "：" + (mode == 0 ? "会议模式" : "通话模式") + ", 麦克1增益" + mic1Gain + "dB" + ", 麦克2增益" + mic2Gain + "dB");
         */
        override fun onMicGain(status: Boolean, mode: Int, mic1Gain: Int, mic2Gain: Int) {

        }

        override fun onPair(status: Boolean) {
            //打印日志
            Log.d("DTingChannel", "onPair: $status")
        }

        override fun onUnpair(status: Boolean) {
            //打印日志
            Log.d("DTingChannel", "onUnpair: $status")
        }

    }


    /**
     * 文件操作回调
     * 处理设备文件相关操作的回调
     */
    private val mFilesCallback: NvEasyBleFilesCallback = object : NvEasyBleFilesCallback {
        override fun onFilesList(filesList: List<NvEasyFile>?) {
            //文件列表回来初始化快传为false
            mFileWifiEnable = false
            handleOnFilesList(filesList)
        }

        override fun onFileStream(
            bleOrWifi: Boolean,
            fileIndex: Int,
            totalPackets: Int,
            currentPacket: Int,
            packetData: ByteArray
        ) {
//            Log.d(
//                "DTingChannel",
//                "文件下载进度 - 文件索引: $fileIndex, 总包数: $totalPackets, 当前包: $currentPacket, 数据大小: ${packetData.size}，bleOrWifi：${bleOrWifi}"
//            )
            //处理文件的下载逻辑
            handleOnFileStream(currentPacket, fileIndex, totalPackets, packetData)
        }

        override fun onWifiStatus(wifiStatus: NvEasyBleFilesCallback.WifiStatus) {
            // WiFi 状态变化
            Log.d("DTingChannel", "WiFi 状态变化: ${wifiStatus.name}")
            eventHandler.sendWifiStatus(wifiStatus.ordinal)

            when (wifiStatus) {
                NvEasyBleFilesCallback.WifiStatus.OPENING -> {
                    Log.d("DTingChannel", "WiFi 开启中")
                    // 清理之前的下载流
                    try {
                        if (mDownloadFileStream != null) {
                            mDownloadFileStream?.close()
                            mDownloadFileStream = null
                        }
                    } catch (e: Exception) {
                        Log.e("DTingChannel", "清理下载流失败: ${e.message}")
                    }
                }

                NvEasyBleFilesCallback.WifiStatus.OPENED -> {
                    Log.d("DTingChannel", "WiFi热点已开启")
                }

                NvEasyBleFilesCallback.WifiStatus.CONNECTING -> {
                    Log.d("DTingChannel", "正在连接WiFi热点")
                }

                NvEasyBleFilesCallback.WifiStatus.CONNECTED -> {
                    Log.d(
                        "DTingChannel",
                        "WifiStatus: 已连接 mDownloadFiles 的大小 = ${mDownloadFiles.size}"
                    )
                    if (mDownloadFiles.isNotEmpty()) {
                        nvEasyBleManager.downloadRecordFiles(
                            currentDevice,
                            mDownloadFiles,
                            true,
                            true
                        )
                    }
                }

                NvEasyBleFilesCallback.WifiStatus.STOPPING -> {
                    Log.d("DTingChannel", "WiFi快传停止中")
                }

                NvEasyBleFilesCallback.WifiStatus.STOPPED -> {
                    Log.d("DTingChannel", "WiFi快传已停止")
                    // 重置WiFi快传状态
                    mFileWifiEnable = false
                }

                NvEasyBleFilesCallback.WifiStatus.CANCELLED -> {
                    //"是否重连AI Note热点？请注意设备上的wifi是否还处于打开状态。"
                    Log.d("DTingChannel", "已经取消Wifi传输")
                }
            }
        }

        override fun onWifiOpened(
            p0: String?,
            p1: Int,
            p2: String?,
            p3: Int,
            p4: String?,
            p5: String?
        ) {

        }

        override fun onFinished(filesList: List<NvEasyFile>) {
            Log.d("DTingChannel", "文件操作完成")
            // 文件操作完成
        }

        override fun onDeleteFile(status: Boolean, sn: Int, fileName: String) {
            // 文件删除结果
        }

        override fun onException(p0: FilesReceiverException?) {
            Log.e("DTingChannel", "文件操作失败: ${p0.toString()}")
        }

    }


}

/**
 * 获取最后一条录音文件
 */
fun BleManager.handleGetLastRecordFile() {
    isLastRecord = true
    nvEasyBleManager.getFilesList(currentDevice)
}

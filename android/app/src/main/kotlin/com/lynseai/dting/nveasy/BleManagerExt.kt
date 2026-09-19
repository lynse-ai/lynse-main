package com.lynseai.dting.nveasy

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.lynseai.dting.utils.LogUtils
import com.nveasy.audio.Constants
import com.nveasy.audio.Opus
import com.nveasy.ble.NoiseCancellation
import com.nveasy.ble.callback.NvEasyBleOTACallback
import com.nveasy.ble.data.NvEasyFile
import com.nveasy.ble.exception.BleException
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.text.SimpleDateFormat
import java.util.Arrays
import java.util.Locale

fun BleManager.handleOnStream(data: ByteArray, frameLen: Int, totalLen: Int) {
    try {
        if (data.isEmpty() || frameLen <= 0 || totalLen <= 0) {
            Log.e("DTingChannel", "无效的数据流参数")
            return
        }

        val totalFrame = totalLen / frameLen
        Log.d("DTingChannel", "开始处理录音数据 - 总帧数: $totalFrame")

        for (i in 0 until totalFrame) {
            val frameData = Arrays.copyOfRange(data, i * frameLen, (i + 1) * frameLen)
            val pcmData = Opus.decode(frameData, audioUtils.FRAME_SIZE)

            if (pcmData != null && pcmData.isNotEmpty()) {
//                Log.d("DTingChannel", "解码成功 - 帧索引: $i, PCM数据大小: ${pcmData.size}")
                audioUtils.writePcmData(pcmData)
            } else {
                Log.e("DTingChannel", "Opus解码失败 - 帧索引: $i")
            }
        }
    } catch (e: Exception) {
        Log.e("DTingChannel", "处理录音数据流异常: ${e.localizedMessage ?: "未知错误"}")
        e.printStackTrace()
    }
}

/**
 * opus 文件转pcm文件 传进来的参数是opus文件path
 * 返回的是pcm文件path
 * 修改为在后台线程执行耗时操作，避免ANR
 */
fun BleManager.opusToPcm(
    opusFilePath: String,
    currentPacket: Int,
    totalPackets: Int,
    fileDuration: Int,
    scene: Int,
    recordStartTime: String,
) {
    // 将整个方法体移到后台线程执行，避免ANR
    Thread {
        try {
            Log.d("DTingChannel", "====fileDuration is $fileDuration 秒")

            val isMeeting = opusFilePath.contains("meeting_")
            Log.d("DTingChannel", "isMeeting is $isMeeting")

            val file = File(opusFilePath)
            if (!file.exists() || file.length() <= 0) {
                Log.e("DTingChannel", "文件不存在或为空")
                return@Thread
            }
            Log.d("DTingChannel", "opusFilePath is $opusFilePath")
            // /data/user/0/com.lynseai.dting/cache/recordings/meeting_2025-09-11 16:11:33:800_sn1_4719298.raw.opus

            val opus: ByteArray = ByteArray(if (audioUtils.isStereo()) 40 else 80)
            Log.d("DTingChannel", "opus 大小 is ${opus.size}")
            NoiseCancellation.processBegin()
            val path = file.toPath()
            val bufferedInputStream = BufferedInputStream(Files.newInputStream(path))

            try {
                while (true) {
                    val opusSize = bufferedInputStream.read(opus)
//                    Log.d("DTingChannel", "opusSize 大小 is ${opusSize}")
                    if (opusSize < 0) {
                        // 在主线程中处理UI更新
                        Handler(Looper.getMainLooper()).post {
                            try {
                                // 在主线程中关闭文件并获取文件信息
                                val fileInfo = audioUtils.closeFile(
                                    AudioUtils.isNoiseCancel(currentDevice?.deviceType),
                                    audioUtils.isStereo()
                                )
                                if (fileInfo != null) {
                                    val mp3Path = fileInfo["mp3Path"]
                                    if (mp3Path != null) {
                                        Log.d("DTingChannel", "mp3Path is $mp3Path")
                                        currentNumber += 1
                                        Log.d(
                                            "DTingChannel",
                                            "mp3Path is $mp3Path ,currentNumber = $currentNumber"
                                        )
                                        eventHandler.sendDownloadFileProgress(
                                            currentPacket,
                                            totalPackets,
                                            currentNumber
                                        )
                                        // 从nvEasyFiles中查找对应的scene值
                                        eventHandler.sendRecordMP3FilePath(
                                            fileInfo["mp3Path"] as String,
                                            fileDuration,
                                            scene,
                                            recordStartTime
                                        )
                                    }
                                    mDownloadFileStream?.close()
                                    //如果是最后一次，我还是需要能够获取到剩余的文件
                                    if (isLastRecord) {
                                        Log.d(
                                            "DTingChannel",
                                            "下载所有文件isLastRecord = ${isLastRecord}"
                                        )
                                        isLastRecord = false
                                        getFileList()
                                    }
                                }
                            } catch (e: Exception) {
                                Log.e("DTingChannel", "处理MP3文件路径异常: ${e.message}")
                                e.printStackTrace()
                            }
                        }
                        break
                    }
                    try {
                        val pcmData = Opus.decode(opus, audioUtils.FRAME_SIZE)
                        if (pcmData != null && pcmData.isNotEmpty()) {
//                            Log.d("DTingChannel", "解码成功 - PCM数据大小: ${pcmData.size}")
                            audioUtils.writePcmData(pcmData)
                        } else {
                            Log.e("DTingChannel", "Opus解码失败")
                        }
                    } catch (e: Exception) {
                        Log.e("DTingChannel", "解码异常: ${e.message}")
                    }
                }

                Log.d("DTingChannel", "保存pcm和mp3文件成功")
                NoiseCancellation.processEnd()
            } finally {
                try {
                    bufferedInputStream.close()
                } catch (e: Exception) {
                    Log.e("DTingChannel", "关闭输入流异常: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e("DTingChannel", "后台处理opusToPcm异常: ${e.localizedMessage}")
            e.printStackTrace()
        }
    }.start()
}

fun BleManager.handleOnFilesList(filesList: List<NvEasyFile>?) {
    if (filesList == null || filesList.isEmpty()) {
        Log.d("DTingChannel", "filesList is empty")
        nvEasyFiles.clear()
        //发送当前文件是空的
        eventHandler.sendFileListReceived(emptyList())
        //                eventHandler.sendFileListReceived(filesList)
        return
    }
    nvEasyFiles.clear()
    nvEasyFiles.addAll(filesList)
    //更新断点续传信息
    updateResumeOffset()
    if (isLastRecord) { //最后录音
        audioUtils.initOpus(true)
        val nvEasyFile = nvEasyFiles.maxByOrNull { it.sn }
        if (nvEasyFile != null) {
            Log.d("DTingChannel", "下载最后的录音文件 sn = ${nvEasyFile.sn}")
            downloadFile(nvEasyFile.sn)
        } else {
            Log.d("DTingChannel", "handleNormalGetFileList")
            handleNormalGetFileList(filesList)
        }
    } else {
        // 文件列表获取结果
        Log.d("DTingChannel", "文件列表获取结果 handleNormalGetFileList")
        handleNormalGetFileList(filesList)
    }

}


/**
 * 正常文件列表获取结果处理
 */
private fun BleManager.handleNormalGetFileList(filesList: List<NvEasyFile>) {
    //            nvEasyFiles = filesList
    val fileList = filesList.map { file ->
        mapOf(
            "sn" to file.sn,
            "name" to file.name,
            "size" to file.size,
            "scene" to file.scene,
            "startTimestamp" to file.startTime,
            "endTimestamp" to file.endTime
        )
    }
    Log.d("DTingChannel", "收到文件列表 - 共 ${filesList.size} 个文件")
    filesList.forEach { file ->
        Log.d(
            "DTingChannel",
            "文件信息 - 名称: ${file.name}, SN: ${file.sn}, 大小: ${file.size}, 开始时间: ${file.startTime}, 结束时间: ${file.endTime}"
        )
    }
    eventHandler.sendFileListReceived(fileList)
    if (filesList.isNotEmpty()) {
        //发送指令，正在下载文件
        val status = if (isLastRecord) 0 else 1
//        eventHandler.sendDownloadAllFileUI(status)
        handleDownloadAllFile()
    }
}

/**
 * 下载所有文件
 */
fun BleManager.handleDownloadAllFile() {
    if (currentDevice == null) {
        Log.e("DTingChannel", "下载失败：设备未连接")
        return
    }
//    audioUtils.initOpus(true)
//    // 创建文件
//    audioUtils.createFile()
    currentNumber = 0
    mDownloadFiles.clear()
    //下载前遍历文件，更新偏移量，并且启动下载
    updateDownloadFilesOffset()
}

// 在 BleManager 中添加变量用于记录状态
var totalReceivedBytes = 0L
var startTimeMillis: Long = 0L
val speedMap = mutableMapOf<Int, Double>() // 记录每个文件(fileIndex)的实时速度


fun BleManager.handleOnFileStream(
    currentPacket: Int,
    fileIndex: Int,
    totalPackets: Int,
    packetData: ByteArray
) {
    try {
        val opusFilePath: String
        val dataLength = packetData.size

        // 初始化计时器和计数器
        if (currentPacket == 1) {
            startTimeMillis = System.currentTimeMillis()
            totalReceivedBytes = 0
        }
        // 累计接收字节数
        totalReceivedBytes += dataLength
        // 计算已用时间（秒）
        val elapsedSeconds = (System.currentTimeMillis() - startTimeMillis) / 1000.0
        // 避免除以零
        if (elapsedSeconds > 0) {
            val speedKbps = (totalReceivedBytes / elapsedSeconds) / 1024.0
            speedMap[fileIndex] = speedKbps
//            Log.d(
//                "DTingChannel",
//                "传输速率: %.2f kb/s (fileIndex: $fileIndex) speedKbps = $speedKbps"
//            )
            // 更新传输速度
            eventHandler.sendFileDownloadSpeed(speedKbps.toInt())
        }

        if (currentPacket == 1) {
            audioUtils.initOpus(true)
            // 创建文件
            audioUtils.createFile()
//            if (mDownloadFileStream != null) {
//                mDownloadFileStream?.close()
//            }
            var fileName: String = ""

            if (nvEasyFiles.isNotEmpty()) {
                var find = nvEasyFiles.find { it.sn == fileIndex }
                if (find != null) {
                    Log.d(
                        "DTingChannel",
                        "=====文件信息 - 名称: ${find.name}, SN: ${find.sn}, 录音时长: ${find.endTime - find.startTime}"
                    )
                    val sceneStr = when (find.scene) {
                        0 -> "meeting_"
                        else -> "call_"
                    }
                    fileName =
                        sceneStr + formatTime(System.currentTimeMillis()) + "_sn" + find.sn + "_" + find.name
                    //断点续传
                    mBPResumeName = find.name
                    Log.d("断点续传", "mBPResumeName = find.name = ${find.name}")
                }
            }
            if (fileName == "") {
                fileName = "call_" + formatTime(System.currentTimeMillis())
            }
            var isBPResumeFile = false
            if (isSupportBreakpointResume()) { //断点续传
                for (downloadFile in mDownloadFiles) {
                    Log.d(
                        "断点续传",
                        "downloadFile.getSn() = ${downloadFile.getSn()}, fileIndex = ${fileIndex}, downloadFile.getOffset() = ${downloadFile.getOffset()},mBPResumeFilePath = ${mBPResumeFilePath}"
                    )
                    if (downloadFile.getSn() == fileIndex && downloadFile.getOffset() > 0 && mBPResumeFilePath != null) {
                        mDownloadFileStream = FileOutputStream(mBPResumeFilePath, true)
                        isBPResumeFile = true
                        break
                    }
                }
            }
            if (!isBPResumeFile) {
                opusDownFilePath = audioUtils.getFilePath(fileName + ".opus")
                Log.d("DTingChannel", "文件保存路径: $opusDownFilePath")
                mDownloadFileStream = FileOutputStream(opusDownFilePath, true)
            }

        }
        //进度实现
        if (totalPackets != currentPacket) {
            eventHandler.sendDownloadFileProgress(currentPacket, totalPackets, currentNumber)
        }
        if (mDownloadFileStream != null) {
            mDownloadFileStream?.write(packetData, 0, packetData.size)
            if (totalPackets == currentPacket) {
                var scene = 0
                var fileDuration = 0
                var find = nvEasyFiles.find { it.sn == fileIndex }
                var recordStartTime = System.currentTimeMillis()
                if (find != null) {
                    fileDuration = (find.endTime - find.startTime).toInt()
                    scene = find.scene
                    recordStartTime = find.startTime * 1000
                }
                opusToPcm(
                    opusDownFilePath,
                    currentPacket,
                    totalPackets,
                    fileDuration,
                    scene,
                    audioUtils.formatTime(recordStartTime)
                )
                Log.d(
                    "DTingChannel",
                    "文件保存完成,文件时长: $fileDuration, 场景: $scene, 开始时间: $recordStartTime ${
                        audioUtils.formatTime(recordStartTime)
                    }"
                )

                for (downloadFile in mDownloadFiles) {
                    if (downloadFile.getSn() == fileIndex) {
                        mDownloadFiles.remove(downloadFile)
                        break
                    }
                }
                // 重置断点续传参数
                if (isSupportBreakpointResume()) {
                    if (fileIndex == mBPResumeSN) {
                        clearResumeDataOffset()
                    }
                }
            } else { //实时保存断点续传
                if (isSupportBreakpointResume()) {
                    mBPResumeSN = fileIndex
                    mBPResumeOffset += packetData.size
                    //前面已经赋值
//                    mBPResumeName = mCurrentFileData.name
                    mBPResumeFilePath = opusDownFilePath
                    //保存到文件
                    updateResumeDataOffset()
                }
            }
        }
    } catch (e: Exception) {
        Log.e("DTingChannel", "文件保存异常: ${e.localizedMessage ?: "未知错误"}")
        mDownloadFileStream?.close()
        mDownloadFileStream = null
        e.printStackTrace()
    }
}

fun BleManager.getDeviceType(): Int {
    if (currentDevice != null) {
        return currentDevice?.getDeviceType() ?: mDeviceType
    }
    return mDeviceType
}

/**
 * 设备升级
 */
fun BleManager.handleDeviceUpdateOta(filePath: String, version: String) {
    val file = File(filePath)
    if (currentDevice != null && file.exists()) {
        nvEasyBleManager.otaUpdate(currentDevice, file, version, object : NvEasyBleOTACallback {
            override fun onPrepared() {
                Log.d("DTingChannel", "准备升级设备")
                eventHandler.sendDeviceUpdateOtaStatus(
                    EventHandler.OtaUpdateStatus.STARTED.value,
                    0,
                    0,
                    ""
                )
            }

            override fun onFail(p0: BleException?) {
                Log.d("DTingChannel", "升级设备失败")
                eventHandler.sendDeviceUpdateOtaStatus(
                    EventHandler.OtaUpdateStatus.FAILED.value,
                    0,
                    0,
                    p0?.description ?: ""
                )
            }

            override fun onSuccess() {
                Log.d("DTingChannel", "升级设备成功")
                eventHandler.sendDeviceUpdateOtaStatus(
                    EventHandler.OtaUpdateStatus.SUCCESS.value,
                    100,
                    0,
                    ""
                )
            }

            override fun onProgress(p0: Int, p1: Int) {
                Log.d("DTingChannel", "升级设备进度：$p0/$p1")
                eventHandler.sendDeviceUpdateOtaStatus(
                    EventHandler.OtaUpdateStatus.PROGRESS.value,
                    p0,
                    p1,
                    ""
                )
            }

        })
    } else {
        eventHandler.sendDeviceUpdateOtaStatus(
            EventHandler.OtaUpdateStatus.FAILED.value,
            0,
            0,
            "currentDevice == null or file is no"
        )
    }
}

/**
 * 开始录音
 * 创建录音文件并启动设备录音
 */
fun BleManager.handleStartRecord() {
    try {
        Log.d("DTingChannel", "开始录音")
        LogUtils.getInstance().d("DTingChannel", "开始录音")
        audioUtils.createFile()

        if (AudioUtils.isNoiseCancel(currentDevice?.deviceType)) {
            Log.d("DTingChannel", "启用降噪处理")
            NoiseCancellation.processBegin()
        }

        currentDevice?.let { device ->
            Log.d("DTingChannel", "发送录音命令到设备 mRecordType = ${mRecordType} 0 是会议")
            mStartRecordTime = System.currentTimeMillis()
            nvEasyBleManager.record(device, 1, mRecordType)
        } ?: run {
            Log.e("DTingChannel", "设备未连接，无法开始录音")
        }
    } catch (e: Exception) {
        Log.e("DTingChannel", "开始录音失败: ${e.localizedMessage ?: "未知错误"}")
        e.printStackTrace()
    }
}

/**
 * 停止录音
 * 停止设备录音并关闭文件
 * @return 包含录音文件信息的Map，包括pcmPath和mp3Path
 */
fun BleManager.handleStopRecord(): Map<String, String>? {
    try {
        Log.d("DTingChannel", "停止录音")

        currentDevice?.let { device ->
            Log.d("DTingChannel", "发送停止录音命令到设备 mRecordType = ${mRecordType} 0 是会议")
            nvEasyBleManager.record(device, 0, mRecordType)
            mEndRecordTime = System.currentTimeMillis()
        } ?: run {
            Log.e("DTingChannel", "设备未连接，无法停止录音")
        }

        if (AudioUtils.isNoiseCancel(currentDevice?.deviceType)) {
            Log.d("DTingChannel", "结束降噪处理")
            NoiseCancellation.processEnd()
        }

        val fileInfo = audioUtils.closeFile(
            AudioUtils.isNoiseCancel(currentDevice?.deviceType),
            audioUtils.isStereo()
        )
        if (fileInfo != null) {
            Log.d(
                "DTingChannel",
                "录音文件已保存 - PCM路径: ${fileInfo.get("pcmPath")}, MP3路径: ${fileInfo.get("mp3Path")}"
            )
            val mp3Path = fileInfo.get("mp3Path")
//            var mp3Duration = 0
            if (mp3Path != null) {
//                val retriever = MediaMetadataRetriever()
//                try {
//                    retriever.setDataSource(mp3Path)
//                    val durationStr =
//                        retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
//                    val durationMs = durationStr?.toLongOrNull() ?: 0
//                    mp3Duration = ((durationMs + 500L) / 1000L).toInt()
//                    Log.d("DTingChannel", "----MP3时长: mp3Duration=${mp3Duration}")
//                } catch (e: Exception) {
//                    Log.e("BleManagerExt", "Error retrieving audio duration", e)
//                    mp3Duration = 0
//                } finally {
//                    retriever.release()
//                }
                //处理时长
                val mp3Duration = (mEndRecordTime - mStartRecordTime) / 1000
                Log.e("DTingChannel", "停止录音 时长: $mp3Duration s")
                // 获取当前录音的scene值，默认为会议模式(0)
                val currentScene = mRecordType // mRecordType: 0是会议模式，1是通话模式
                eventHandler.sendRecordMP3FilePath(
                    mp3Path,
                    mp3Duration.toInt(),
                    currentScene,
                    audioUtils.formatTime(mStartRecordTime)
                )
            }
        } else {
            //这个时候就应该拉取最后的一条录音记录
            Log.e("DTingChannel", "这个时候就应该拉取最后的一条录音记录")
            nvEasyBleManager.stopDownloadFiles(currentDevice)
            //延迟三秒
            Handler(Looper.getMainLooper()).postDelayed({
                handleGetLastRecordFile()
            }, 3000)
        }

        return fileInfo
    } catch (e: Exception) {
        Log.e("DTingChannel", "停止录音失败: ${e.localizedMessage ?: "未知错误"}")
        e.printStackTrace()
        return null
    }
}

fun BleManager.handleDownloadFile(fileSN: Int, isWifi: Boolean = false) {
    if (currentDevice == null) {
        Log.e("DTingChannel", "下载失败：设备未连接")
        return
    }
    // 创建文件
    audioUtils.createFile()
    mDownloadFiles.clear()
    updateDownloadFileOffset(fileSN, isWifi)
    Log.e(
        "DTingChannel",
        "下载失败：未找到 SN 为 $fileSN 的文件 mDownloadFiles的大小= ${mDownloadFiles.size}"
    )
}


/**
 * 时间格式化
 * 格式化时间戳为字符串
 * @param date 时间戳
 * @return 格式化后的字符串
 */
fun BleManager.formatTime(date: Long): String {
    return SimpleDateFormat("yyyy-MM-dd HH:mm:ss:SSS", Locale.getDefault()).format(
        java.util.Date(
            date
        )
    )

}

fun BleManager.isStereo(): Boolean {
    return CHANNELS.value == Constants.Channels.stereo.value
}
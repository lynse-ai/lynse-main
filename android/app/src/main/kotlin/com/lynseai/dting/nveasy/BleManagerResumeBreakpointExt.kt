package com.lynseai.dting.nveasy

import android.annotation.SuppressLint
import android.text.TextUtils
import android.util.Log
import com.lynseai.dting.utils.LogUtils
import com.lynseai.dting.utils.MMKVUtils
import com.nveasy.ble.data.NvEasyBleDevice
import com.nveasy.ble.data.NvEasyDownloadFile
import java.io.File

/**
 * BleManager 扩展类，处理断点续传
 */


/**
 * 更新断点续传的偏移量
 */
fun BleManager.updateResumeOffset() {
    if (isSupportBreakpointResume()) {
        var resumeFile: File? = null
        if (!TextUtils.isEmpty(mBPResumeFilePath)) {
//            Log.i(TAG, "断点续传文件已存在: " + mBPResumeFilePath)
            resumeFile = File(mBPResumeFilePath)
//            LogUtils.getInstance().i(TAG, "断点续传文件已存在: " + mBPResumeFilePath)
        }
        if (resumeFile != null && resumeFile.exists()) {
            if (resumeFile.length() != mBPResumeOffset.toLong()) {
//                Log.i(TAG, "断点续传文件已存在，但偏移量不一致，删除重新下载: " + resumeFile.absolutePath)
//                LogUtils.getInstance().i(TAG, "断点续传文件已存在，但偏移量不一致，删除重新下载: " + resumeFile.absolutePath)
                mBPResumeOffset = resumeFile.length().toInt()
            }
        } else {
//            Log.i(TAG, "断点续传文件不存在")
//            LogUtils.getInstance().i(TAG, "断点续传文件不存在")
            mBPResumeOffset = 0
            mBPResumeSN = mBPResumeOffset
            mBPResumeFilePath = null
            mBPResumeName = mBPResumeFilePath
        }
    }

}

/**
 * 检查设备是否支持断点续传功能
 * 只有协议版本大于等于16的设备才支持断点续传
 * @return true表示支持断点续传，false表示不支持
 */
fun BleManager.isSupportBreakpointResume(): Boolean {
    return currentDevice != null && currentDevice!!.protocolVersion >= NvEasyBleDevice.PROTOCOL_VERSION_16
}


/**
 * 更新BLE设备引用
 * @param bleDevice 新的BLE设备对象
 */
fun BleManager.updateBleDevice(bleDevice: NvEasyBleDevice?) {
    this.currentDevice = bleDevice

    // 如果新设备不支持断点续传，清除所有断点信息
    if (!isSupportBreakpointResume()) {
        clearResumeDataOffset()
    }
}

/**
 * 获取断点续传状态信息（用于调试）
 * @return 断点续传状态字符串
 */
@SuppressLint("DefaultLocale")
fun BleManager.getBreakpointStatus(): String {
    if (!isSupportBreakpointResume()) {
        return "设备不支持断点续传"
    }

    if (mBPResumeSN == 0) {
        return "无断点续传信息"
    }

    return String.format(
        "断点续传: SN=%d, Offset=%d, Name=%s, Path=%s",
        mBPResumeSN,
        mBPResumeOffset,
        mBPResumeName,
        mBPResumeFilePath
    )
}

/**
 * 更新下载列表文件的偏移量
 */
fun BleManager.updateDownloadFilesOffset() {
    val downloadFiles: MutableList<NvEasyDownloadFile> = ArrayList<NvEasyDownloadFile>()
    for (file in nvEasyFiles) {
        val downloadFile = NvEasyDownloadFile()
        downloadFile.setSn(file.sn)
        downloadFile.setOffset(0)
        var isResumeFile = false
        if (isSupportBreakpointResume() && file.sn == mBPResumeSN && file.name.equals(mBPResumeName) && !TextUtils.isEmpty(mBPResumeFilePath)) {
            downloadFile.setOffset(mBPResumeOffset)
            isResumeFile = true
        }
        if (isResumeFile) {
            downloadFiles.add(0, downloadFile)
        } else {
            downloadFiles.add(downloadFile)
        }
    }
    mDownloadFiles.clear()
    mDownloadFiles.addAll(downloadFiles)
    nvEasyBleManager.downloadRecordFiles(currentDevice, mDownloadFiles, true, false)
//    Log.e("断点续传", "的文件 mDownloadFiles的大小= ${mDownloadFiles.size}")
//    LogUtils.getInstance().e("断点续传", "的文件 mDownloadFiles的大小= ${mDownloadFiles.size}")
}

/**
 * 更新单个文件的偏移量，传文件的sn进来
 */
fun BleManager.updateDownloadFileOffset(sn: Int, isWifi: Boolean) {
    for (file in nvEasyFiles) {
        if (file.sn == sn) {
            val downloadFile = NvEasyDownloadFile()
            downloadFile.setSn(file.sn)
            downloadFile.setOffset(0)
            var isResumeFile = false
            if (isSupportBreakpointResume() && file.sn == mBPResumeSN && file.name.equals(mBPResumeName) && !TextUtils.isEmpty(mBPResumeFilePath)) {
                downloadFile.setOffset(mBPResumeOffset)
                isResumeFile = true
            }
            if (isResumeFile) {
                mDownloadFiles.add(0, downloadFile)
            } else {
                mDownloadFiles.add(downloadFile)
            }
//            Log.d(
//                "断点续传",
//                "准备下载文件 - 名称: ${file.name}, SN: ${file.sn}, 大小: ${file.size}, 开始时间: ${file.startTime}, 结束时间: ${file.endTime}"
//            )
//            LogUtils.getInstance().d("断点续传", "准备下载文件 - 名称: ${file.name}, SN: ${file.sn}, 大小: ${file.size}, 开始时间: ${file.startTime}, 结束时间: ${file.endTime}")
            if (!isWifi) {
                nvEasyBleManager.downloadRecordFiles(currentDevice, mDownloadFiles, true, false)
            }
            return
        }
    }
}

/**
 * 获取断点续传的信息
 */
fun BleManager.getResumeDataOffset() {
    try {
        if (mBpResumeDeviceMac != null) {
            mBPResumeSN = MMKVUtils.getInstance().getBPResumeSN(mBpResumeDeviceMac!!)
            mBPResumeOffset = MMKVUtils.getInstance().getBPResumeOffset(mBpResumeDeviceMac!!)
            mBPResumeName = MMKVUtils.getInstance().getBPResumeName(mBpResumeDeviceMac!!)
            mBPResumeFilePath = MMKVUtils.getInstance().getBPResumeFilePath(mBpResumeDeviceMac!!)
        }
//        Log.d(
//            "断点续传",
//            "获取断点续传信息 - 文件序列号: $mBPResumeSN, 偏移量: $mBPResumeOffset, 文件名: $mBPResumeName, 文件路径: $mBPResumeFilePath,设备Mac：=${mBpResumeDeviceMac}"
//        )
//        LogUtils.getInstance().v("断点续传", "获取断点续传信息 - 文件序列号: $mBPResumeSN, 偏移量: $mBPResumeOffset, 文件名: $mBPResumeName, 文件路径: $mBPResumeFilePath,设备Mac：=${mBpResumeDeviceMac}")
    } catch (e: Exception) {
        Log.e("断点续传", "获取断点续传信息异常: ${e.localizedMessage}")
        LogUtils.getInstance().e("断点续传", "获取断点续传信息异常: ${e.localizedMessage}")
    }

}

/**
 * 更新断点续传信息
 */
fun BleManager.updateResumeDataOffset() {
    try {
        if (mBPResumeSN != 0 && mBPResumeOffset != 0 && mBPResumeName != null && mBPResumeFilePath != null) {
//            Log.d(
//                "断点续传",
//                "更新断点续传信息 - 文件序列号: $mBPResumeSN, 偏移量: $mBPResumeOffset, 文件名: $mBPResumeName, 文件路径: $mBPResumeFilePath, 设备Mac：=${mBpResumeDeviceMac}"
//            )
//            LogUtils.getInstance().d("断点续传", "更新断点续传信息 - 文件序列号: $mBPResumeSN, 偏移量: $mBPResumeOffset, 文件名: $mBPResumeName, 文件路径: $mBPResumeFilePath")
            if (mBpResumeDeviceMac != null) {
                MMKVUtils.getInstance().saveBPResumeSN(mBPResumeSN, mBpResumeDeviceMac!!)
                MMKVUtils.getInstance().saveBPResumeOffset(mBPResumeOffset, mBpResumeDeviceMac!!)
                MMKVUtils.getInstance().saveBPResumeName(mBPResumeName, mBpResumeDeviceMac!!)
                MMKVUtils.getInstance().saveBPResumeFilePath(mBPResumeFilePath, mBpResumeDeviceMac!!)
            }

        } else {
            Log.d("断点续传", "更新断点续传信息失败 文件序列号: $mBPResumeSN, 偏移量: $mBPResumeOffset, 文件名: $mBPResumeName, 文件路径: $mBPResumeFilePath")
            LogUtils.getInstance().d("断点续传", "更新断点续传信息失败 文件序列号: $mBPResumeSN, 偏移量: $mBPResumeOffset, 文件名: $mBPResumeName, 文件路径: $mBPResumeFilePath")
        }
    } catch (e: Exception) {
        Log.e("断点续传", "更新断点续传信息异常: ${e.localizedMessage}")
    }
}

/**
 * 清除断点续传信息
 */
fun BleManager.clearResumeDataOffset() {
    try {
        Log.d("断点续传", "清除断点续传信息 mBpResumeDeviceMac = ${mBpResumeDeviceMac}")
        LogUtils.getInstance().d("断点续传","清除断点续传信息 mBpResumeDeviceMac = ${mBpResumeDeviceMac}")
        if (mBpResumeDeviceMac != null) {
            MMKVUtils.getInstance().clearBreakpointResumeInfo(mBpResumeDeviceMac!!)
            mBPResumeSN = 0
            mBPResumeOffset = 0
            mBPResumeName = null
            mBPResumeFilePath = null
            Log.d("断点续传", "清除断点续传信息")
        }
    } catch (e: Exception) {
        Log.e("断点续传", "清除断点续传信息异常: ${e.localizedMessage}")
        LogUtils.getInstance().d("断点续传","清除断点续传信息异常: ${e.localizedMessage}")
    }
}
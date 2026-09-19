package com.lynseai.dting.nveasy

import android.content.Context
import android.media.AudioFormat
import android.os.Environment
import android.util.Log
import com.nveasy.audio.Constants
import com.nveasy.audio.Mp3Converter
import com.nveasy.audio.Opus
import com.nveasy.ble.NoiseCancellation
import com.nveasy.ble.data.NvEasyBleDevice
import java.io.BufferedOutputStream
import java.io.File
import java.nio.file.Files
import java.text.SimpleDateFormat
import java.util.*

/**
 * AudioUtils 类负责音频处理相关功能
 * 包括：
 * - Opus 编解码器的初始化和管理
 * - PCM 音频数据的录制和保存
 * - PCM 转 MP3 格式的转换
 * - 音频文件的管理
 */
class AudioUtils(private val context: Context) {
    // 采样率：16000Hz
    private val SAMPLE_RATE: Int = Constants.SampleRate._16000.value

    // 帧大小，用于 Opus 解码
    val FRAME_SIZE: Int
        get() = frameSize
    private var frameSize: Int = Constants.FrameSize._640.value

    // 声道配置：单声道/立体声
    private var CHANNELS: Constants.Channels = Constants.Channels.mono

    // 音频编码格式：16位 PCM
    private val ENCODING_BIT: Int = AudioFormat.ENCODING_PCM_16BIT

    // PCM 数据输出流
    private  var mPcmStream: BufferedOutputStream? = null

    // PCM 文件对象
    private lateinit var mPcmFile: File

    // MP3 文件对象
    private lateinit var mMp3File: File

    // 当前录音的文件名（不包含扩展名）
    private var currentFileName: String = ""

    /**
     * 初始化 Opus 解码器
     * @param mono true 表示单声道，false 表示立体声
     */
    fun initOpus(mono: Boolean) {
        CHANNELS = if (mono) Constants.Channels.mono else Constants.Channels.stereo
        frameSize = if (mono) Constants.FrameSize._640.value else Constants.FrameSize._1280.value
        Log.d("DTingChannel", "初始化Opus解析：FRAME_SIZE:$frameSize,SAMPLE_RATE:$SAMPLE_RATE,CHANNELS:${CHANNELS.value}")
        Opus.decoderRelease()
        Opus.decoderInit(SAMPLE_RATE, CHANNELS.value)
    }

    /**
     * 创建音频文件
     * 使用当前时间戳作为文件名，创建 PCM 和 MP3 文件
     */
    fun createFile() {
        currentFileName = formatTime(System.currentTimeMillis())
        val pcmFilePath = getFilePath("$currentFileName.pcm")
        val mp3FilePath = getFilePath("$currentFileName.mp3")

        mPcmFile = File(pcmFilePath)
        mMp3File = File(mp3FilePath)

        // 确保父目录存在
        mPcmFile.parentFile?.mkdirs()

        val result = mPcmFile.createNewFile()
        if (result) {
            mPcmStream = BufferedOutputStream(Files.newOutputStream(mPcmFile.toPath()))
            Log.d("DTingChannel", "创建PCM文件成功：$pcmFilePath")
        } else {
            Log.e("DTingChannel", "创建PCM文件失败")
        }
    }

    /**
     * 关闭音频文件并进行格式转换
     * @param isNoiseCancel 是否启用降噪
     * @param isStereo 是否为立体声
     * @return 包含 PCM 和 MP3 文件路径的 Map
     */
    fun closeFile(isNoiseCancel: Boolean, isStereo: Boolean): Map<String, String>? {
        // 关闭 PCM 文件流
        if (mPcmStream ==  null) {
            Log.e("DTingChannel", "PCM文件流为空")
            return null
        }
        mPcmStream?.flush()
        mPcmStream?.close()

        val pcmFilePath = mPcmFile.absolutePath
        val mp3FilePath = mMp3File.absolutePath
        val fileName = currentFileName

        // 在后台线程中执行MP3转换
            try {
                // 初始化 MP3 转换器
                Mp3Converter.init(
                    SAMPLE_RATE,      // 输入采样率
                    CHANNELS.value,   // 声道数
                    0,               // 输入比特率（0表示自动）
                    SAMPLE_RATE,      // 输出采样率
                    96,              // 输出比特率
                    7                // 音质等级（0-9，9为最高质量）
                )

                // 执行 PCM 到 MP3 的转换
                Mp3Converter.convertMp3(
                    if (isNoiseCancel) false else isStereo,
                    pcmFilePath,
                    mp3FilePath
                )

                // 记录转换结果
                Log.d("DTingChannel", "------结束录音-----")
                Log.d("DTingChannel", "SAMPLE_RATE:$SAMPLE_RATE，CHANNELS:${CHANNELS.value}")
                Log.d("DTingChannel", "isNoiseCancel:$isNoiseCancel isStereo:$isStereo")
                Log.d("DTingChannel", "mPcmFile文件大小:${mPcmFile.length()}，mMp3File文件大小:${mMp3File.length()}")
                Log.d("DTingChannel", "PCM文件保存到: $pcmFilePath")
                Log.d("DTingChannel", "MP3文件保存到: $mp3FilePath")
            } catch (e: Exception) {
                Log.e("DTingChannel", "MP3转换异常: ${e.message}")
                e.printStackTrace()
            }

        // 立即返回文件路径，不等待MP3转换完成
        return mapOf(
            "pcmPath" to pcmFilePath,
            "mp3Path" to mp3FilePath,
            "fileName" to fileName
        )
    }
    
    
    /**
     * 写入 PCM 音频数据
     * @param pcmData PCM 格式的音频数据
     */
    fun writePcmData(pcmData: ByteArray) {
        if (pcmData.isNotEmpty()) {
            try {
                mPcmStream?.write(pcmData)
                mPcmStream?.flush()  // 立即写入文件
            } catch (e: Exception) {
                Log.e("DTingChannel", "写入PCM数据失败: ${e.message}")
            }
        }
    }

    /**
     * 获取文件存储路径
     * @param fileName 文件名
     * @return 完整的文件路径
     */
    fun getFilePath(fileName: String): String {
//        val baseDir = context.getExternalFilesDir(Environment.DIRECTORY_MUSIC)?.absolutePath
        val baseDir = context.cacheDir.absolutePath  // 内部缓存目录（私有）
        val recordDir = File(baseDir, "recordings")
        if (!recordDir.exists()) {
            recordDir.mkdirs()
        }
        return recordDir.absolutePath + File.separator + fileName
    }

    /**
     * 格式化时间戳
     * @param date 时间戳（毫秒）
     * @return 格式化后的时间字符串（yyyy-MM-dd HH:mm:ss）
     */
    fun formatTime(date: Long): String {
        return SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(date))
    }

    /**
     * 检查是否为立体声模式
     * @return true 表示立体声，false 表示单声道
     */
    fun isStereo(): Boolean {
        return CHANNELS.value == Constants.Channels.stereo.value
    }

    /**
     * 获取当前 PCM 文件路径
     * @return PCM 文件的绝对路径，如果文件不存在则返回 null
     */
    fun getCurrentPcmPath(): String? {
        return if (::mPcmFile.isInitialized && mPcmFile.exists()) {
            mPcmFile.absolutePath
        } else {
            null
        }
    }

    companion object {
        /**
         * 检查设备是否支持降噪功能
         * 注：当前由于降噪导致音频转换问题，暂时禁用此功能
         * @param deviceType 设备类型
         * @return 是否支持降噪
         */
        fun isNoiseCancel(deviceType: Int?): Boolean {
            return false
            // 由于降噪导致音频转换有问题，暂时设置为false
            // return (deviceType == NvEasyBleDevice.AI_NOTES || deviceType == NvEasyBleDevice.AI_CASE)
        }
    }
}
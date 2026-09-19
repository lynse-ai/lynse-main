package com.lynseai.dting.utils

import android.content.Context
import com.tencent.mmkv.MMKV
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json

/**
 * MMKV工具类 - 单例模式
 * 用于存储断点续传信息和其他应用数据
 */
class MMKVUtils private constructor() {

    companion object {
        @Volatile
        private var INSTANCE: MMKVUtils? = null

        // MMKV实例
        private var mmkv: MMKV? = null

        // JSON序列化器
        private val json = Json {
            ignoreUnknownKeys = true
            encodeDefaults = true
        }

        // 断点续传信息的键
        private const val KEY_BREAKPOINT_RESUME_INFO = "breakpoint_resume_info"

        // 单个字段的键（兼容旧版本）
        private const val KEY_BP_RESUME_SN = "bp_resume_sn"
        private const val KEY_BP_RESUME_OFFSET = "bp_resume_offset"
        private const val KEY_BP_RESUME_NAME = "bp_resume_name"
        private const val KEY_BP_RESUME_FILE_PATH = "bp_resume_file_path"

        /**
         * 获取单例实例
         */
        fun getInstance(): MMKVUtils {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: MMKVUtils().also { INSTANCE = it }
            }
        }

        /**
         * 初始化MMKV
         * 需要在Application中调用
         */
        fun initialize(context: Context) {
            MMKV.initialize(context)
            mmkv = MMKV.defaultMMKV()
        }
    }

    /**
     * 检查MMKV是否已初始化
     */
    private fun checkInitialized() {
        if (mmkv == null) {
            println("MMKV未初始化，请先调用MMKVUtils.initialize(context)")
        }
    }

    // ==================== 断点续传信息存储方法 ====================

    /**
     * 保存断点续传信息对象
     */
    fun saveBreakpointResumeInfo(info: BreakpointResumeInfo) {
        checkInitialized()
        try {
            val jsonString = json.encodeToString(info)
            mmkv?.encode(KEY_BREAKPOINT_RESUME_INFO, jsonString)
        } catch (e: Exception) {
            e.printStackTrace()
            // 如果序列化失败，使用单个字段保存
//            saveBreakpointResumeInfoFields(info)
        }
    }

    /**
     * 获取断点续传信息对象
     */
//    fun getBreakpointResumeInfo(): BreakpointResumeInfo {
//        checkInitialized()
//        return try {
//            val jsonString = mmkv?.decodeString(KEY_BREAKPOINT_RESUME_INFO)
//            if (!jsonString.isNullOrEmpty()) {
//                json.decodeFromString<BreakpointResumeInfo>(jsonString)
//            } else {
//                // 如果没有对象数据，尝试从单个字段读取（兼容旧版本）
//                getBreakpointResumeInfoFromFields()
//            }
//        } catch (e: Exception) {
//            e.printStackTrace()
//            // 如果反序列化失败，尝试从单个字段读取
//            getBreakpointResumeInfoFromFields()
//        }
//    }

    /**
     * 清空断点续传信息
     */
    fun clearBreakpointResumeInfo(deviceMac: String) {
        checkInitialized()
        mmkv?.removeValueForKey(KEY_BREAKPOINT_RESUME_INFO + deviceMac)
        // 同时清空单个字段（兼容性）
        mmkv?.removeValueForKey(KEY_BP_RESUME_SN + deviceMac)
        mmkv?.removeValueForKey(KEY_BP_RESUME_OFFSET + deviceMac)
        mmkv?.removeValueForKey(KEY_BP_RESUME_NAME + deviceMac)
        mmkv?.removeValueForKey(KEY_BP_RESUME_FILE_PATH + deviceMac)
    }

    /**
     * 检查是否存在断点续传信息
     */
    fun hasBreakpointResumeInfo(): Boolean {
        checkInitialized()
        return mmkv?.containsKey(KEY_BREAKPOINT_RESUME_INFO) == true ||
                mmkv?.containsKey(KEY_BP_RESUME_SN) == true
    }

    // ==================== 单个字段存储方法（兼容性和便利性） ====================

    /**
     * 保存断点续传文件序列号
     */
    fun saveBPResumeSN(sn: Int, deviceMac: String) {
        checkInitialized()
        mmkv?.encode(KEY_BP_RESUME_SN + deviceMac, sn)
    }

    /**
     * 获取断点续传文件序列号
     */
    fun getBPResumeSN(deviceMac: String): Int {
        checkInitialized()
        return mmkv?.decodeInt(KEY_BP_RESUME_SN + deviceMac, 0) ?: 0
    }

    /**
     * 保存断点续传偏移量
     */
    fun saveBPResumeOffset(offset: Int, deviceMac: String) {
        checkInitialized()
        mmkv?.encode(KEY_BP_RESUME_OFFSET + deviceMac, offset)
    }

    /**
     * 获取断点续传偏移量
     */
    fun getBPResumeOffset(deviceMac: String): Int {
        checkInitialized()
        return mmkv?.decodeInt(KEY_BP_RESUME_OFFSET + deviceMac, 0) ?: 0
    }

    /**
     * 保存断点续传文件名
     */
    fun saveBPResumeName(name: String?, deviceMac: String) {
        checkInitialized()
        if (name != null) {
            mmkv?.encode(KEY_BP_RESUME_NAME + deviceMac, name)
        } else {
            mmkv?.removeValueForKey(KEY_BP_RESUME_NAME + deviceMac)
        }
    }

    /**
     * 获取断点续传文件名
     */
    fun getBPResumeName(deviceMac: String): String? {
        checkInitialized()
        return mmkv?.decodeString(KEY_BP_RESUME_NAME + deviceMac)
    }

    /**
     * 保存断点续传文件路径
     */
    fun saveBPResumeFilePath(filePath: String?, deviceMac: String) {
        checkInitialized()
        if (filePath != null) {
            mmkv?.encode(KEY_BP_RESUME_FILE_PATH + deviceMac, filePath)
        } else {
            mmkv?.removeValueForKey(KEY_BP_RESUME_FILE_PATH + deviceMac)
        }
    }

    /**
     * 获取断点续传文件路径
     */
    fun getBPResumeFilePath(deviceMac: String): String? {
        checkInitialized()
        return mmkv?.decodeString(KEY_BP_RESUME_FILE_PATH + deviceMac)
    }

    // ==================== 私有辅助方法 ====================

    /**
     * 使用单个字段保存断点续传信息
     */
//    private fun saveBreakpointResumeInfoFields(info: BreakpointResumeInfo) {
//        saveBPResumeSN(info.mBPResumeSN)
//        saveBPResumeOffset(info.mBPResumeOffset)
//        saveBPResumeName(info.mBPResumeName)
//        saveBPResumeFilePath(info.mBPResumeFilePath)
//    }

    /**
     * 从单个字段读取断点续传信息
     */
//    private fun getBreakpointResumeInfoFromFields(): BreakpointResumeInfo {
//        return BreakpointResumeInfo(
//            mBPResumeSN = getBPResumeSN(),
//            mBPResumeOffset = getBPResumeOffset(),
//            mBPResumeName = getBPResumeName(),
//            mBPResumeFilePath = getBPResumeFilePath()
//        )
//    }

    // ==================== 通用存储方法 ====================

    /**
     * 存储字符串
     */
    fun putString(key: String, value: String?) {
        checkInitialized()
        if (value != null) {
            mmkv?.encode(key, value)
        } else {
            mmkv?.removeValueForKey(key)
        }
    }

    /**
     * 获取字符串
     */
    fun getString(key: String, defaultValue: String? = null): String? {
        checkInitialized()
        return mmkv?.decodeString(key, defaultValue)
    }

    /**
     * 存储整数
     */
    fun putInt(key: String, value: Int) {
        checkInitialized()
        mmkv?.encode(key, value)
    }

    /**
     * 获取整数
     */
    fun getInt(key: String, defaultValue: Int = 0): Int {
        checkInitialized()
        return mmkv?.decodeInt(key, defaultValue) ?: defaultValue
    }

    /**
     * 存储布尔值
     */
    fun putBoolean(key: String, value: Boolean) {
        checkInitialized()
        mmkv?.encode(key, value)
    }

    /**
     * 获取布尔值
     */
    fun getBoolean(key: String, defaultValue: Boolean = false): Boolean {
        checkInitialized()
        return mmkv?.decodeBool(key, defaultValue) ?: defaultValue
    }

    /**
     * 存储长整数
     */
    fun putLong(key: String, value: Long) {
        checkInitialized()
        mmkv?.encode(key, value)
    }

    /**
     * 获取长整数
     */
    fun getLong(key: String, defaultValue: Long = 0L): Long {
        checkInitialized()
        return mmkv?.decodeLong(key, defaultValue) ?: defaultValue
    }

    /**
     * 存储浮点数
     */
    fun putFloat(key: String, value: Float) {
        checkInitialized()
        mmkv?.encode(key, value)
    }

    /**
     * 获取浮点数
     */
    fun getFloat(key: String, defaultValue: Float = 0f): Float {
        checkInitialized()
        return mmkv?.decodeFloat(key, defaultValue) ?: defaultValue
    }

    /**
     * 删除指定键的值
     */
    fun remove(key: String) {
        checkInitialized()
        mmkv?.removeValueForKey(key)
    }

    /**
     * 检查是否包含指定键
     */
    fun contains(key: String): Boolean {
        checkInitialized()
        return mmkv?.containsKey(key) ?: false
    }

    /**
     * 清空所有数据
     */
    fun clearAll() {
        checkInitialized()
        mmkv?.clearAll()
    }
}
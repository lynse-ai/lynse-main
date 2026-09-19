package com.lynseai.dting.utils

import kotlinx.serialization.Serializable

/**
 * 断点续传信息数据类
 */
@Serializable
data class BreakpointResumeInfo(
    var mBPResumeSN: Int = 0,                    // 断点续传文件序列号
    var mBPResumeOffset: Int = 0,                // 断点续传偏移量（已下载的字节数）
    var mBPResumeName: String? = null,           // 断点续传文件名
    var mBPResumeFilePath: String? = null        // 断点续传文件路径
) {
    /**
     * 检查是否有有效的断点续传信息
     */
    fun isValid(): Boolean {
        return mBPResumeSN > 0 && 
               mBPResumeOffset >= 0 && 
               !mBPResumeName.isNullOrEmpty() && 
               !mBPResumeFilePath.isNullOrEmpty()
    }

    /**
     * 清空断点续传信息
     */
    fun clear() {
        mBPResumeSN = 0
        mBPResumeOffset = 0
        mBPResumeName = null
        mBPResumeFilePath = null
    }

    /**
     * 复制断点续传信息
     */
    fun copyFrom(other: BreakpointResumeInfo) {
        this.mBPResumeSN = other.mBPResumeSN
        this.mBPResumeOffset = other.mBPResumeOffset
        this.mBPResumeName = other.mBPResumeName
        this.mBPResumeFilePath = other.mBPResumeFilePath
    }
}
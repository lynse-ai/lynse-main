package com.lynseai.dting.utils;

import android.annotation.SuppressLint;
import android.text.TextUtils;
import android.util.Log;

import com.nveasy.ble.data.NvEasyBleDevice;
import com.nveasy.ble.data.NvEasyDownloadFile;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.List;

/**
 * 断点续传管理器
 * 负责管理文件下载的断点续传功能，包括断点信息的保存、恢复和清除
 * 
 * 主要功能：
 * 1. 检查设备是否支持断点续传
 * 2. 保存和恢复断点续传信息
 * 3. 处理文件下载流程中的断点续传逻辑
 * 4. 清除断点续传信息
 */
public class BreakpointResumeManager {
    
    private static final String TAG = "BreakpointResumeManager";
    
    // 断点续传信息
    private int mBPResumeSN = 0;           // 断点续传文件序列号
    private int mBPResumeOffset = 0;       // 断点续传偏移量（已下载的字节数）
    private String mBPResumeName = null;   // 断点续传文件名
    private String mBPResumeFilePath = null; // 断点续传文件路径
    
    // BLE设备引用
    private NvEasyBleDevice mBleDevice;
    
    /**
     * 构造函数
     * @param bleDevice BLE设备对象
     */
    public BreakpointResumeManager(NvEasyBleDevice bleDevice) {
        this.mBleDevice = bleDevice;
    }
    
    /**
     * 检查设备是否支持断点续传功能
     * 只有协议版本大于等于16的设备才支持断点续传
     * @return true表示支持断点续传，false表示不支持
     */
    public boolean isSupportBreakpointResume() {
        return mBleDevice != null && mBleDevice.getProtocolVersion() >= NvEasyBleDevice.PROTOCOL_VERSION_16;
    }
    
    /**
     * 保存断点续传信息
     * @param sn 文件序列号
     * @param offset 已下载的字节数
     * @param name 文件名
     * @param filePath 文件路径
     */
    public void saveBreakpointInfo(int sn, int offset, String name, String filePath) {
        if (!isSupportBreakpointResume()) {
            Log.w(TAG, "设备不支持断点续传，无法保存断点信息");
            return;
        }
        
        this.mBPResumeSN = sn;
        this.mBPResumeOffset = offset;
        this.mBPResumeName = name;
        this.mBPResumeFilePath = filePath;
        
        Log.i(TAG, "保存断点续传信息: SN=" + sn + ", Offset=" + offset + ", Name=" + name);
    }
    
    /**
     * 清除断点续传信息
     * @param completedSN 已完成下载的文件序列号，如果与当前断点续传文件匹配则清除
     */
    public void clearBreakpointInfo(int completedSN) {
        if (!isSupportBreakpointResume()) {
            return;
        }
        
        if (completedSN == mBPResumeSN) {
            Log.i(TAG, "清除断点续传信息: SN=" + mBPResumeSN);
            mBPResumeSN = 0;
            mBPResumeOffset = 0;
            mBPResumeName = null;
            mBPResumeFilePath = null;
        }
    }
    
    /**
     * 清除所有断点续传信息
     */
    public void clearAllBreakpointInfo() {
        Log.i(TAG, "清除所有断点续传信息");
        mBPResumeSN = 0;
        mBPResumeOffset = 0;
        mBPResumeName = null;
        mBPResumeFilePath = null;
    }
    
    /**
     * 检查指定文件是否为断点续传文件
     * @param sn 文件序列号
     * @param name 文件名
     * @return true表示是断点续传文件，false表示不是
     */
    public boolean isBreakpointResumeFile(int sn, String name) {
        return isSupportBreakpointResume() && 
               sn == mBPResumeSN && 
               name != null && name.equals(mBPResumeName) &&
               !TextUtils.isEmpty(mBPResumeFilePath);
    }
    
    /**
     * 为下载文件列表设置断点续传偏移量
     * @param downloadFiles 下载文件列表
     */
    public void setupDownloadFilesOffset(List<NvEasyDownloadFile> downloadFiles) {
        if (!isSupportBreakpointResume() || downloadFiles == null) {
            return;
        }
        
        for (NvEasyDownloadFile downloadFile : downloadFiles) {
            if (downloadFile.getSn() == mBPResumeSN && mBPResumeOffset > 0) {
                downloadFile.setOffset(mBPResumeOffset);
                Log.i(TAG, "设置断点续传偏移量: SN=" + mBPResumeSN + ", Offset=" + mBPResumeOffset);
                break;
            }
        }
    }
    
    /**
     * 创建断点续传文件输出流
     * @param filePath 文件路径
     * @return FileOutputStream对象，如果创建失败返回null
     */
    public FileOutputStream createResumeFileStream(String filePath) {
        try {
            return new FileOutputStream(filePath, true); // append模式
        } catch (IOException e) {
            Log.e(TAG, "创建断点续传文件输出流失败: " + e.getMessage());
            return null;
        }
    }
    
    /**
     * 检查断点续传文件是否存在
     * @return true表示文件存在，false表示不存在
     */
    public boolean isBreakpointFileExists() {
        if (!isSupportBreakpointResume() || TextUtils.isEmpty(mBPResumeFilePath)) {
            return false;
        }
        
        File file = new File(mBPResumeFilePath);
        return file.exists() && file.length() >= mBPResumeOffset;
    }
    
    // Getter方法
    public int getBPResumeSN() {
        return mBPResumeSN;
    }
    
    public int getBPResumeOffset() {
        return mBPResumeOffset;
    }
    
    public String getBPResumeName() {
        return mBPResumeName;
    }
    
    public String getBPResumeFilePath() {
        return mBPResumeFilePath;
    }
    
    /**
     * 更新BLE设备引用
     * @param bleDevice 新的BLE设备对象
     */
    public void updateBleDevice(NvEasyBleDevice bleDevice) {
        this.mBleDevice = bleDevice;
        
        // 如果新设备不支持断点续传，清除所有断点信息
        if (!isSupportBreakpointResume()) {
            clearAllBreakpointInfo();
        }
    }
    
    /**
     * 获取断点续传状态信息（用于调试）
     * @return 断点续传状态字符串
     */
    @SuppressLint("DefaultLocale")
    public String getBreakpointStatus() {
        if (!isSupportBreakpointResume()) {
            return "设备不支持断点续传";
        }
        
        if (mBPResumeSN == 0) {
            return "无断点续传信息";
        }
        
        return String.format("断点续传: SN=%d, Offset=%d, Name=%s, Path=%s", mBPResumeSN, mBPResumeOffset, mBPResumeName, mBPResumeFilePath);
    }
}
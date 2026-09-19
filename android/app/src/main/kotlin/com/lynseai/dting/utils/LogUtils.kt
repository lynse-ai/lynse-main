package com.lynseai.dting.utils

import android.content.Context
import android.os.Environment
import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.channels.consumeEach
import java.io.File
import java.io.FileWriter
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 日志工具类 - 单例模式
 * 支持文件写入、按日期分文件、自动清理和并发处理
 * 
 * 特性：
 * - 按日期创建日志文件（每天一个文件）
 * - 自动清理超过7天的日志文件
 * - 使用协程和Channel处理并发日志写入
 * - 支持不同日志级别
 * - 线程安全
 * - 自动创建日志目录
 */
class LogUtils private constructor() {
    
    companion object {
        @Volatile
        private var INSTANCE: LogUtils? = null
        
        // 日志级别
        const val VERBOSE = 2
        const val DEBUG = 3
        const val INFO = 4
        const val WARN = 5
        const val ERROR = 6
        
        // 日志级别字符串
        private val LEVEL_NAMES = mapOf(
            VERBOSE to "V",
            DEBUG to "D",
            INFO to "I",
            WARN to "W",
            ERROR to "E"
        )
        
        // 默认配置
        private const val DEFAULT_LOG_DIR = "logs"
        private const val DEFAULT_MAX_DAYS = 7
        private const val DEFAULT_CHANNEL_CAPACITY = 1000
        private const val DEFAULT_TAG = "LogUtils"
        
        /**
         * 获取单例实例
         */
        fun getInstance(): LogUtils {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: LogUtils().also { INSTANCE = it }
            }
        }
    }
    
    // 配置参数
    private var context: Context? = null
    private var logDir: String = DEFAULT_LOG_DIR
    private var maxDays: Int = DEFAULT_MAX_DAYS
    private var isEnabled: Boolean = true
    private var minLogLevel: Int = VERBOSE
    private var enableConsoleLog: Boolean = true
    private var enableFileLog: Boolean = true
    
    // 日志处理相关
    private val logChannel = Channel<LogEntry>(DEFAULT_CHANNEL_CAPACITY)
    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val isInitialized = AtomicBoolean(false)
    private val fileWriters = ConcurrentHashMap<String, FileWriter>()
    
    // 日期格式化器
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
    private val timeFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
    
    /**
     * 日志条目数据类
     */
    private data class LogEntry(
        val level: Int,
        val tag: String,
        val message: String,
        val throwable: Throwable? = null,
        val timestamp: Long = System.currentTimeMillis()
    )
    
    /**
     * 初始化日志工具
     * 
     * @param context 应用上下文
     * @param logDir 日志目录名（相对于应用私有目录）
     * @param maxDays 最大保留天数
     * @param minLogLevel 最小日志级别
     * @param enableConsoleLog 是否启用控制台日志
     * @param enableFileLog 是否启用文件日志
     */
    fun initialize(
        context: Context,
        logDir: String = DEFAULT_LOG_DIR,
        maxDays: Int = DEFAULT_MAX_DAYS,
        minLogLevel: Int = VERBOSE,
        enableConsoleLog: Boolean = true,
        enableFileLog: Boolean = true
    ) {
        if (isInitialized.compareAndSet(false, true)) {
            this.context = context.applicationContext
            this.logDir = logDir
            this.maxDays = maxDays
            this.minLogLevel = minLogLevel
            this.enableConsoleLog = enableConsoleLog
            this.enableFileLog = enableFileLog
            
            // 启动日志处理协程
            startLogProcessor()
            
            // 清理旧日志文件
            cleanOldLogFiles()
            
            Log.i(DEFAULT_TAG, "LogUtils initialized successfully")
        }
    }
    
    /**
     * 启动日志处理协程
     */
    private fun startLogProcessor() {
        coroutineScope.launch {
            logChannel.consumeEach { logEntry ->
                try {
                    processLogEntry(logEntry)
                } catch (e: Exception) {
                    Log.e(DEFAULT_TAG, "Error processing log entry", e)
                }
            }
        }
    }
    
    /**
     * 处理日志条目
     */
    private suspend fun processLogEntry(logEntry: LogEntry) {
        // 控制台日志
        if (enableConsoleLog) {
            writeToConsole(logEntry)
        }
        
        // 文件日志
        if (enableFileLog && context != null) {
            writeToFile(logEntry)
        }
    }
    
    /**
     * 写入控制台日志
     */
    private fun writeToConsole(logEntry: LogEntry) {
        val message = if (logEntry.throwable != null) {
            "${logEntry.message}\n${Log.getStackTraceString(logEntry.throwable)}"
        } else {
            logEntry.message
        }
        
        when (logEntry.level) {
            VERBOSE -> Log.v(logEntry.tag, message)
            DEBUG -> Log.d(logEntry.tag, message)
            INFO -> Log.i(logEntry.tag, message)
            WARN -> Log.w(logEntry.tag, message)
            ERROR -> Log.e(logEntry.tag, message)
        }
    }
    
    /**
     * 写入文件日志
     */
    private suspend fun writeToFile(logEntry: LogEntry) = withContext(Dispatchers.IO) {
        try {
            val logFile = getLogFile()
            val writer = getFileWriter(logFile)
            
            val timestamp = timeFormat.format(Date(logEntry.timestamp))
            val levelName = LEVEL_NAMES[logEntry.level] ?: "U"
            val processId = android.os.Process.myPid()
            val threadId = Thread.currentThread().id
            
            val logLine = buildString {
                append("$timestamp $levelName/$processId-$threadId ${logEntry.tag}: ${logEntry.message}")
                if (logEntry.throwable != null) {
                    append("\n")
                    append(Log.getStackTraceString(logEntry.throwable))
                }
                append("\n")
            }
            
            synchronized(writer) {
                writer.write(logLine)
                writer.flush()
            }
        } catch (e: Exception) {
            Log.e(DEFAULT_TAG, "Error writing to log file", e)
        }
    }
    
    /**
     * 获取当天的日志文件
     */
    private fun getLogFile(): File {
        val context = this.context ?: throw IllegalStateException("LogUtils not initialized")
        
        val logDirFile = File(context.filesDir, logDir)
        if (!logDirFile.exists()) {
            logDirFile.mkdirs()
        }
        
        val today = dateFormat.format(Date())
        return File(logDirFile, "log_$today.txt")
    }
    
    /**
     * 获取文件写入器（缓存复用）
     */
    private fun getFileWriter(logFile: File): FileWriter {
        val filePath = logFile.absolutePath
        return fileWriters.computeIfAbsent(filePath) { path ->
            try {
                FileWriter(path, true) // 追加模式
            } catch (e: IOException) {
                Log.e(DEFAULT_TAG, "Error creating FileWriter for $path", e)
                throw e
            }
        }
    }
    
    /**
     * 清理旧的日志文件
     */
    private fun cleanOldLogFiles() {
        coroutineScope.launch {
            try {
                val context = this@LogUtils.context ?: return@launch
                val logDirFile = File(context.filesDir, logDir)
                
                if (!logDirFile.exists()) return@launch
                
                val currentTime = System.currentTimeMillis()
                val maxAge = maxDays * 24 * 60 * 60 * 1000L // 转换为毫秒
                
                logDirFile.listFiles()?.forEach { file ->
                    if (file.isFile && file.name.startsWith("log_") && file.name.endsWith(".txt")) {
                        val fileAge = currentTime - file.lastModified()
                        if (fileAge > maxAge) {
                            // 关闭对应的FileWriter
                            fileWriters.remove(file.absolutePath)?.close()
                            
                            if (file.delete()) {
                                Log.d(DEFAULT_TAG, "Deleted old log file: ${file.name}")
                            } else {
                                Log.w(DEFAULT_TAG, "Failed to delete old log file: ${file.name}")
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(DEFAULT_TAG, "Error cleaning old log files", e)
            }
        }
    }
    
    /**
     * 发送日志到处理队列
     */
    private fun sendLog(level: Int, tag: String, message: String, throwable: Throwable? = null) {
        if (!isEnabled || level < minLogLevel || !isInitialized.get()) {
            return
        }
        
        val logEntry = LogEntry(level, tag, message, throwable)
        
        // 尝试发送到队列，如果队列满了则丢弃（避免阻塞）
        if (!logChannel.trySend(logEntry).isSuccess) {
            Log.w(DEFAULT_TAG, "Log channel is full, dropping log entry")
        }
    }
    
    // ==================== 公共日志方法 ====================
    
    /**
     * Verbose级别日志
     */
    fun v(tag: String, message: String) {
        sendLog(VERBOSE, tag, message)
    }
    
    fun v(tag: String, message: String, throwable: Throwable) {
        sendLog(VERBOSE, tag, message, throwable)
    }
    
    /**
     * Debug级别日志
     */
    fun d(tag: String, message: String) {
        sendLog(DEBUG, tag, message)
    }
    
    fun d(tag: String, message: String, throwable: Throwable) {
        sendLog(DEBUG, tag, message, throwable)
    }
    
    /**
     * Info级别日志
     */
    fun i(tag: String, message: String) {
        sendLog(INFO, tag, message)
    }
    
    fun i(tag: String, message: String, throwable: Throwable) {
        sendLog(INFO, tag, message, throwable)
    }
    
    /**
     * Warning级别日志
     */
    fun w(tag: String, message: String) {
        sendLog(WARN, tag, message)
    }
    
    fun w(tag: String, message: String, throwable: Throwable) {
        sendLog(WARN, tag, message, throwable)
    }
    
    /**
     * Error级别日志
     */
    fun e(tag: String, message: String) {
        sendLog(ERROR, tag, message)
    }
    
    fun e(tag: String, message: String, throwable: Throwable) {
        sendLog(ERROR, tag, message, throwable)
    }
    
    // ==================== 配置方法 ====================
    
    /**
     * 启用或禁用日志
     */
    fun setEnabled(enabled: Boolean) {
        this.isEnabled = enabled
    }
    
    /**
     * 设置最小日志级别
     */
    fun setMinLogLevel(level: Int) {
        this.minLogLevel = level
    }
    
    /**
     * 启用或禁用控制台日志
     */
    fun setConsoleLogEnabled(enabled: Boolean) {
        this.enableConsoleLog = enabled
    }
    
    /**
     * 启用或禁用文件日志
     */
    fun setFileLogEnabled(enabled: Boolean) {
        this.enableFileLog = enabled
    }
    
    /**
     * 获取日志文件列表
     */
    fun getLogFiles(): List<File> {
        val context = this.context ?: return emptyList()
        val logDirFile = File(context.filesDir, logDir)
        
        if (!logDirFile.exists()) return emptyList()
        
        return logDirFile.listFiles()?.filter { file ->
            file.isFile && file.name.startsWith("log_") && file.name.endsWith(".txt")
        }?.sortedByDescending { it.lastModified() } ?: emptyList()
    }
    
    /**
     * 获取当前日志文件大小（字节）
     */
    fun getCurrentLogFileSize(): Long {
        return try {
            getLogFile().length()
        } catch (e: Exception) {
            0L
        }
    }
    
    /**
     * 手动清理所有日志文件
     */
    fun clearAllLogs() {
        coroutineScope.launch {
            try {
                val context = this@LogUtils.context ?: return@launch
                val logDirFile = File(context.filesDir, logDir)
                
                if (!logDirFile.exists()) return@launch
                
                // 关闭所有FileWriter
                fileWriters.values.forEach { writer ->
                    try {
                        writer.close()
                    } catch (e: Exception) {
                        Log.e(DEFAULT_TAG, "Error closing FileWriter", e)
                    }
                }
                fileWriters.clear()
                
                // 删除所有日志文件
                logDirFile.listFiles()?.forEach { file ->
                    if (file.isFile && file.name.startsWith("log_") && file.name.endsWith(".txt")) {
                        if (file.delete()) {
                            Log.d(DEFAULT_TAG, "Deleted log file: ${file.name}")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(DEFAULT_TAG, "Error clearing all logs", e)
            }
        }
    }
    
    /**
     * 释放资源
     */
    fun release() {
        coroutineScope.launch {
            try {
                // 关闭所有FileWriter
                fileWriters.values.forEach { writer ->
                    try {
                        writer.close()
                    } catch (e: Exception) {
                        Log.e(DEFAULT_TAG, "Error closing FileWriter", e)
                    }
                }
                fileWriters.clear()
                
                // 关闭Channel
                logChannel.close()
                
                // 取消协程作用域
                coroutineScope.cancel()
                
                Log.i(DEFAULT_TAG, "LogUtils released successfully")
            } catch (e: Exception) {
                Log.e(DEFAULT_TAG, "Error releasing LogUtils", e)
            }
        }
    }
}
package com.lynseai.dting.utils

import android.content.Context
import android.util.Log

/**
 * LogUtils 使用示例
 * 演示如何使用日志工具类的各种功能
 */
object LogUtilsExample {
    
    private const val TAG = "LogUtilsExample"
    
    /**
     * 初始化日志工具的示例
     */
    fun initializeLogUtils(context: Context) {
        // 基本初始化
        LogUtils.getInstance().initialize(context)
        
        // 自定义配置初始化
        LogUtils.getInstance().initialize(
            context = context,
            logDir = "app_logs",           // 自定义日志目录
            maxDays = 10,                  // 保留10天的日志
            minLogLevel = LogUtils.DEBUG,  // 最小日志级别为DEBUG
            enableConsoleLog = true,       // 启用控制台日志
            enableFileLog = true           // 启用文件日志
        )
        
        Log.i(TAG, "LogUtils initialized with custom configuration")
    }
    
    /**
     * 基本日志使用示例
     */
    fun basicLoggingExample() {
        val logUtils = LogUtils.getInstance()
        
        // 不同级别的日志
        logUtils.v(TAG, "This is a verbose log message")
        logUtils.d(TAG, "This is a debug log message")
        logUtils.i(TAG, "This is an info log message")
        logUtils.w(TAG, "This is a warning log message")
        logUtils.e(TAG, "This is an error log message")
        
        // 带异常的日志
        try {
            throw RuntimeException("Test exception")
        } catch (e: Exception) {
            logUtils.e(TAG, "An error occurred", e)
        }
    }
    
    /**
     * 高并发日志测试示例
     */
    fun concurrentLoggingExample() {
        val logUtils = LogUtils.getInstance()
        
        // 模拟多线程并发写入日志
        repeat(10) { threadIndex ->
            Thread {
                repeat(100) { logIndex ->
                    logUtils.i(TAG, "Thread $threadIndex - Log $logIndex: ${System.currentTimeMillis()}")
                    
                    // 模拟一些处理时间
                    Thread.sleep(1)
                }
            }.start()
        }
        
        Log.i(TAG, "Started concurrent logging test with 10 threads, 100 logs each")
    }
    
    /**
     * 配置管理示例
     */
    fun configurationExample() {
        val logUtils = LogUtils.getInstance()
        
        // 动态调整日志级别
        logUtils.setMinLogLevel(LogUtils.WARN) // 只记录WARNING和ERROR级别的日志
        logUtils.w(TAG, "This warning will be logged")
        logUtils.d(TAG, "This debug message will be ignored")
        
        // 禁用控制台日志，只写入文件
        logUtils.setConsoleLogEnabled(false)
        logUtils.setFileLogEnabled(true)
        logUtils.i(TAG, "This will only be written to file")
        
        // 重新启用控制台日志
        logUtils.setConsoleLogEnabled(true)
        logUtils.i(TAG, "This will be written to both console and file")
        
        // 临时禁用所有日志
        logUtils.setEnabled(false)
        logUtils.e(TAG, "This log will be ignored")
        
        // 重新启用日志
        logUtils.setEnabled(true)
        logUtils.i(TAG, "Logging is enabled again")
    }
    
    /**
     * 文件管理示例
     */
    fun fileManagementExample() {
        val logUtils = LogUtils.getInstance()
        
        // 获取当前日志文件大小
        val currentSize = logUtils.getCurrentLogFileSize()
        logUtils.i(TAG, "Current log file size: $currentSize bytes")
        
        // 获取所有日志文件
        val logFiles = logUtils.getLogFiles()
        logUtils.i(TAG, "Total log files: ${logFiles.size}")
        
        logFiles.forEach { file ->
            logUtils.i(TAG, "Log file: ${file.name}, size: ${file.length()} bytes, modified: ${file.lastModified()}")
        }
        
        // 清理所有日志文件（谨慎使用）
        // logUtils.clearAllLogs()
    }
    
    /**
     * 应用生命周期管理示例
     */
    fun lifecycleManagementExample() {
        val logUtils = LogUtils.getInstance()
        
        // 在应用退出时释放资源
        Runtime.getRuntime().addShutdownHook(Thread {
            logUtils.i(TAG, "Application is shutting down, releasing LogUtils resources")
            logUtils.release()
        })
    }
    
    /**
     * 性能测试示例
     */
    fun performanceTestExample() {
        val logUtils = LogUtils.getInstance()
        val messageCount = 10000
        
        // 测试日志写入性能
        val startTime = System.currentTimeMillis()
        
        repeat(messageCount) { index ->
            logUtils.i(TAG, "Performance test message $index with timestamp ${System.currentTimeMillis()}")
        }
        
        val endTime = System.currentTimeMillis()
        val duration = endTime - startTime
        
        logUtils.i(TAG, "Performance test completed: $messageCount messages in ${duration}ms")
        logUtils.i(TAG, "Average: ${duration.toFloat() / messageCount}ms per message")
    }
    
    /**
     * 错误处理示例
     */
    fun errorHandlingExample() {
        val logUtils = LogUtils.getInstance()
        
        // 模拟各种错误情况
        try {
            // 网络错误
            throw java.net.SocketTimeoutException("Network timeout")
        } catch (e: Exception) {
            logUtils.e(TAG, "Network error occurred", e)
        }
        
        try {
            // 数据解析错误
            throw org.json.JSONException("Invalid JSON format")
        } catch (e: Exception) {
            logUtils.e(TAG, "JSON parsing error", e)
        }
        
        try {
            // 空指针异常
            val nullString: String? = null
            nullString!!.length
        } catch (e: Exception) {
            logUtils.e(TAG, "Null pointer exception", e)
        }
    }
    
    /**
     * 运行所有示例
     */
    fun runAllExamples(context: Context) {
        Log.i(TAG, "=== Starting LogUtils Examples ===")
        
        // 初始化
        initializeLogUtils(context)
        
        // 等待初始化完成
        Thread.sleep(100)
        
        // 运行各种示例
        basicLoggingExample()
        configurationExample()
        fileManagementExample()
        performanceTestExample()
        errorHandlingExample()
        
        // 并发测试放在最后，因为它会产生大量日志
        concurrentLoggingExample()
        
        // 生命周期管理
        lifecycleManagementExample()
        
        Log.i(TAG, "=== LogUtils Examples Completed ===")
    }
}
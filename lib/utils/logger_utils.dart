import 'package:logger/logger.dart';
import 'file_logger_utils.dart';

/// 日志工具类
/// 支持控制台和文件双重输出
class LoggerUtils {
  static Logger? _logger;
  static bool _fileLogEnabled = true;
  
  /// 获取Logger实例
  static Logger get _instance {
    _logger ??= Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
    );
    return _logger!;
  }
  
  /// 初始化日志系统（包括文件日志）
  static Future<void> initialize() async {
    await FileLoggerUtils.instance.initialize();
  }
  
  /// 启用/禁用文件日志
  static void setFileLogEnabled(bool enabled) {
    _fileLogEnabled = enabled;
  }
  
  /// 调试日志
  static void d(String message, [dynamic error, StackTrace? stackTrace]) {
    _instance.d(message, error: error, stackTrace: stackTrace);
    if (_fileLogEnabled) {
      FileLoggerUtils.d(message, error, stackTrace);
    }
  }
  
  /// 信息日志
  static void i(String message, [dynamic error, StackTrace? stackTrace]) {
    _instance.i(message, error: error, stackTrace: stackTrace);
    if (_fileLogEnabled) {
      FileLoggerUtils.i(message, error, stackTrace);
    }
  }
  
  /// 警告日志
  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    _instance.w(message, error: error, stackTrace: stackTrace);
    if (_fileLogEnabled) {
      FileLoggerUtils.w(message, error, stackTrace);
    }
  }
  
  /// 错误日志
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _instance.e(message, error: error, stackTrace: stackTrace);
    if (_fileLogEnabled) {
      FileLoggerUtils.e(message, error, stackTrace);
    }
  }
  
  /// 致命错误日志
  static void f(String message, [dynamic error, StackTrace? stackTrace]) {
    _instance.f(message, error: error, stackTrace: stackTrace);
    if (_fileLogEnabled) {
      FileLoggerUtils.f(message, error, stackTrace);
    }
  }
  
  /// 详细日志
  static void v(String message, [dynamic error, StackTrace? stackTrace]) {
    _instance.t(message, error: error, stackTrace: stackTrace);
    if (_fileLogEnabled) {
      FileLoggerUtils.d(message, error, stackTrace);
    }
  }
  
  /// 记录崩溃日志（专门用于应用崩溃）
  static void crash(String message, dynamic error, StackTrace? stackTrace) {
    _instance.f(message, error: error, stackTrace: stackTrace);
    if (_fileLogEnabled) {
      FileLoggerUtils.crash(message, error, stackTrace);
    }
  }
  
  // === 文件日志管理方法 ===
  
  /// 获取日志目录路径
  static Future<String?> getLogDirectoryPath() {
    return FileLoggerUtils.getLogDirectoryPath();
  }
  
  /// 获取今天的日志文件路径
  static Future<String?> getTodayLogFilePath() {
    return FileLoggerUtils.getTodayLogFilePath();
  }
  
  /// 获取所有日志文件列表
  static Future<List<dynamic>> getAllLogFiles() {
    return FileLoggerUtils.getAllLogFiles();
  }
  
  /// 读取指定日期的日志内容
  static Future<String?> readLogByDate(DateTime date) {
    return FileLoggerUtils.readLogByDate(date);
  }
  
  /// 清空所有日志文件
  static Future<void> clearAllLogs() {
    return FileLoggerUtils.clearAllLogs();
  }
  
  /// 获取日志文件总大小（字节）
  static Future<int> getLogsTotalSize() {
    return FileLoggerUtils.getLogsTotalSize();
  }
  
  /// 格式化文件大小显示
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

/// 文件日志工具类
/// 支持将日志写入文件，自动轮转，最多保存7天
class FileLoggerUtils {
  static FileLoggerUtils? _instance;
  static FileLoggerUtils get instance => _instance ??= FileLoggerUtils._();
  
  FileLoggerUtils._();
  
  Logger? _logger;
  Directory? _logDirectory;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _timeFormat = DateFormat('HH:mm:ss.SSS');
  
  /// 初始化文件日志
  Future<void> initialize() async {
    try {
      // 获取应用缓存目录
      final cacheDir = await getTemporaryDirectory();
      _logDirectory = Directory('${cacheDir.path}/logs');
      
      // 创建日志目录
      if (!await _logDirectory!.exists()) {
        await _logDirectory!.create(recursive: true);
      }
      
      // 清理过期日志文件
      await _cleanOldLogs();
      
      // 初始化Logger
      _logger = Logger(
        printer: _FileLogPrinter(),
        output: _FileOutput(_logDirectory!),
      );
      
      // 记录初始化成功
      await _writeToFile('INFO', '文件日志系统初始化成功');
    } catch (e) {
      // 文件日志初始化失败，静默处理
    }
  }
  
  /// 清理7天前的日志文件
  Future<void> _cleanOldLogs() async {
    try {
      if (_logDirectory == null || !await _logDirectory!.exists()) return;
      
      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(days: 7));
      
      await for (final entity in _logDirectory!.list()) {
        if (entity is File && entity.path.endsWith('.txt')) {
          final fileName = entity.path.split('/').last;
          final dateStr = fileName.replaceAll('.txt', '');
          
          try {
            final fileDate = DateTime.parse(dateStr);
            if (fileDate.isBefore(cutoffDate)) {
              await entity.delete();
              // 删除过期日志文件: $fileName
            }
          } catch (e) {
            // 文件名格式不正确，跳过
            continue;
          }
        }
      }
    } catch (e) {
      // 清理日志文件失败，静默处理
    }
  }
  
  /// 写入日志到文件
  Future<void> _writeToFile(String level, String message, [dynamic error, StackTrace? stackTrace]) async {
    try {
      if (_logDirectory == null) return;
      
      final now = DateTime.now();
      final dateStr = _dateFormat.format(now);
      final timeStr = _timeFormat.format(now);
      
      final logFile = File('${_logDirectory!.path}/$dateStr.txt');
      
      // 构建日志内容
      final logEntry = StringBuffer();
      logEntry.write('[$timeStr] [$level] $message');
      
      if (error != null) {
        logEntry.write('\nError: $error');
      }
      
      if (stackTrace != null) {
        logEntry.write('\nStackTrace: $stackTrace');
      }
      
      logEntry.write('\n');
      
      // 追加写入文件
      await logFile.writeAsString(
        logEntry.toString(),
        mode: FileMode.append,
        encoding: utf8,
      );
    } catch (e) {
      // 写入日志文件失败，静默处理
    }
  }
  
  /// 调试日志
  static Future<void> d(String message, [dynamic error, StackTrace? stackTrace]) async {
    await instance._writeToFile('DEBUG', message, error, stackTrace);
    instance._logger?.d(message, error: error, stackTrace: stackTrace);
  }
  
  /// 信息日志
  static Future<void> i(String message, [dynamic error, StackTrace? stackTrace]) async {
    await instance._writeToFile('INFO', message, error, stackTrace);
    instance._logger?.i(message, error: error, stackTrace: stackTrace);
  }
  
  /// 警告日志
  static Future<void> w(String message, [dynamic error, StackTrace? stackTrace]) async {
    await instance._writeToFile('WARN', message, error, stackTrace);
    instance._logger?.w(message, error: error, stackTrace: stackTrace);
  }
  
  /// 错误日志
  static Future<void> e(String message, [dynamic error, StackTrace? stackTrace]) async {
    await instance._writeToFile('ERROR', message, error, stackTrace);
    instance._logger?.e(message, error: error, stackTrace: stackTrace);
  }
  
  /// 致命错误日志
  static Future<void> f(String message, [dynamic error, StackTrace? stackTrace]) async {
    await instance._writeToFile('FATAL', message, error, stackTrace);
    instance._logger?.f(message, error: error, stackTrace: stackTrace);
  }
  
  /// 记录崩溃日志
  static Future<void> crash(String message, dynamic error, StackTrace? stackTrace) async {
    await instance._writeToFile('CRASH', message, error, stackTrace);
    instance._logger?.f(message, error: error, stackTrace: stackTrace);
  }
  
  /// 获取日志目录路径
  static Future<String?> getLogDirectoryPath() async {
    await instance.initialize();
    return instance._logDirectory?.path;
  }
  
  /// 获取今天的日志文件路径
  static Future<String?> getTodayLogFilePath() async {
    await instance.initialize();
    if (instance._logDirectory == null) return null;
    
    final today = instance._dateFormat.format(DateTime.now());
    return '${instance._logDirectory!.path}/$today.txt';
  }
  
  /// 获取所有日志文件列表
  static Future<List<File>> getAllLogFiles() async {
    await instance.initialize();
    final files = <File>[];
    
    if (instance._logDirectory == null || !await instance._logDirectory!.exists()) {
      return files;
    }
    
    await for (final entity in instance._logDirectory!.list()) {
      if (entity is File && entity.path.endsWith('.txt')) {
        files.add(entity);
      }
    }
    
    // 按文件名排序（日期排序）
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
  
  /// 读取指定日期的日志内容
  static Future<String?> readLogByDate(DateTime date) async {
    await instance.initialize();
    if (instance._logDirectory == null) return null;
    
    final dateStr = instance._dateFormat.format(date);
    final logFile = File('${instance._logDirectory!.path}/$dateStr.txt');
    
    if (await logFile.exists()) {
      return await logFile.readAsString(encoding: utf8);
    }
    
    return null;
  }
  
  /// 清空所有日志文件
  static Future<void> clearAllLogs() async {
    await instance.initialize();
    if (instance._logDirectory == null || !await instance._logDirectory!.exists()) {
      return;
    }
    
    await for (final entity in instance._logDirectory!.list()) {
      if (entity is File && entity.path.endsWith('.txt')) {
        await entity.delete();
      }
    }
  }
  
  /// 获取日志文件总大小（字节）
  static Future<int> getLogsTotalSize() async {
    await instance.initialize();
    int totalSize = 0;
    
    if (instance._logDirectory == null || !await instance._logDirectory!.exists()) {
      return totalSize;
    }
    
    await for (final entity in instance._logDirectory!.list()) {
      if (entity is File && entity.path.endsWith('.txt')) {
        final stat = await entity.stat();
        totalSize += stat.size;
      }
    }
    
    return totalSize;
  }
}

/// 自定义文件日志打印器
class _FileLogPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final time = DateTime.now().toString().substring(11, 23);
    final level = event.level.name.toUpperCase();
    return ['[$time] [$level] ${event.message}'];
  }
}

/// 自定义文件输出器
class _FileOutput extends LogOutput {
  final Directory logDirectory;
  
  _FileOutput(this.logDirectory);
  
  @override
  void output(OutputEvent event) {
    // 这里不需要实现，因为我们直接在_writeToFile中处理文件写入
  }
}
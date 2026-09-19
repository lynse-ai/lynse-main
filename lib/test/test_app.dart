import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) async {
  // 解析命令行参数
  final parser = ArgParser()
    ..addOption('package', abbr: 'p', help: '应用包名 (e.g., com.example.app)')
    ..addOption('output', abbr: 'o', help: '输出文件路径', defaultsTo: 'test_report.txt')
    ..addFlag('performance', abbr: 'f', help: '启用性能监控')
    ..addOption('device', abbr: 'd', help: '指定设备ID')
    ..addFlag('help', abbr: 'h', help: '显示帮助信息', negatable: false);

  final results = parser.parse(arguments);

  if (results['help'] || results['package'] == null) {
    print(parser.usage);
    return;
  }

  final packageName = results['package'] as String;
  final outputFile = results['output'] as String;
  final enablePerformance = results['performance'] as bool;
  final deviceId = results['device'] as String?;

  // 获取项目根目录
  final projectRoot = Directory.current.parent.parent.path;

  // 创建测试报告
  final report = TestReport(packageName: packageName);

  try {
    // 1. 检查Flutter环境
    await _checkFlutterEnvironment(report);

    // 2. 构建应用
    await _buildApp(projectRoot, report);

    // 3. 安装应用
    await _installApp(packageName, projectRoot, deviceId, report);

    // 4. 运行单元测试
    await _runUnitTests(projectRoot, report);

    // 5. 运行集成测试
    await _runIntegrationTests(projectRoot, report);

    // 6. 运行性能测试
    if (enablePerformance) {
      await _runPerformanceTests(packageName, projectRoot, deviceId, report);
    }

    // 7. 运行Monkey测试
    await _runMonkeyTest(packageName, deviceId, report);

    // 8. 运行自定义功能测试
    await _runCustomTests(packageName, deviceId, report);
  } catch (e) {
    report.addError('测试过程中发生异常: $e');
  } finally {
    // 保存报告
    await _saveReport(report, outputFile);

    // 卸载应用
    await _uninstallApp(packageName, deviceId);

    print('测试完成！报告已保存至: $outputFile');
    print('发现的问题: ${report.errors.length}');
    print('性能问题: ${report.performanceIssues.length}');

    // 生成测试总结
    _generateTestSummary(report);
  }
}

class TestReport {
  final String packageName;
  final List<String> logs = [];
  final List<String> errors = [];
  final List<String> warnings = [];
  final List<String> performanceIssues = [];
  final Map<String, dynamic> testMetrics = {};

  TestReport({required this.packageName});

  void addLog(String message) {
    logs.add('[$packageName] $message');
    print(message);
  }

  void addError(String error) {
    errors.add('[$packageName] ERROR: $error');
    stderr.writeln('ERROR: $error');
  }

  void addWarning(String warning) {
    warnings.add('[$packageName] WARNING: $warning');
    print('WARNING: $warning');
  }

  void addPerformanceIssue(String issue) {
    performanceIssues.add('[$packageName] PERFORMANCE: $issue');
    print('PERFORMANCE: $issue');
  }

  void addTestMetric(String name, dynamic value) {
    testMetrics[name] = value;
  }

  Map<String, dynamic> toJson() {
    return {
      'packageName': packageName,
      'timestamp': DateTime.now().toIso8601String(),
      'logs': logs,
      'errors': errors,
      'warnings': warnings,
      'performanceIssues': performanceIssues,
      'testMetrics': testMetrics,
    };
  }
}

Future<void> _checkFlutterEnvironment(TestReport report) async {
  try {
    report.addLog('检查Flutter环境...');

    // 检查Flutter是否可用
    final flutterResult = await Process.run('flutter', ['--version']);
    if (flutterResult.exitCode != 0) {
      report.addError('Flutter环境未配置正确: ${flutterResult.stderr}');
      return;
    }

    // 检查ADB是否可用
    final adbResult = await Process.run('adb', ['--version']);
    if (adbResult.exitCode != 0) {
      report.addError('ADB环境未配置正确: ${adbResult.stderr}');
      return;
    }

    report.addLog('Flutter环境正常: ${flutterResult.stdout}');
    report.addLog('ADB环境正常: ${adbResult.stdout}');
  } catch (e) {
    report.addError('环境检查失败: $e');
  }
}

Future<void> _buildApp(String projectRoot, TestReport report) async {
  try {
    report.addLog('正在构建应用...');

    // 使用绝对路径执行命令
    final flutterPath = _findFlutterExecutable();
    final buildCmd = '$flutterPath build apk';

    final result = await Process.run(
        Platform.isWindows ? 'cmd' : 'sh',
        [Platform.isWindows ? '/c' : '-c', buildCmd],
        workingDirectory: projectRoot
    );

    if (result.exitCode != 0) {
      report.addError('构建失败: ${result.stderr}');
      report.addLog('构建详细输出: ${result.stdout}');
    } else {
      report.addLog('应用构建成功');
    }
  } catch (e) {
    report.addError('构建过程中出错: $e');
  }
}

String _findFlutterExecutable() {
  // 检查环境变量
  final flutterHome = Platform.environment['FLUTTER_HOME'];
  if (flutterHome != null) {
    return path.join(flutterHome, 'bin', Platform.isWindows ? 'flutter.bat' : 'flutter');
  }

  // 检查PATH
  final pathDirs = Platform.environment['PATH']?.split(Platform.pathSeparator) ?? [];
  for (final dir in pathDirs) {
    final flutterPath = path.join(dir, Platform.isWindows ? 'flutter.bat' : 'flutter');
    if (File(flutterPath).existsSync()) {
      return flutterPath;
    }
  }

  // 默认返回
  return 'flutter';
}

Future<void> _installApp(String packageName, String projectRoot, String? deviceId, TestReport report) async {
  try {
    report.addLog('正在安装应用: $packageName');

    // 获取APK路径
    final apkPath = path.join(projectRoot, 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');

    final installCmd = deviceId != null
        ? 'adb -s $deviceId install $apkPath'
        : 'adb install $apkPath';

    final result = await Process.run(
        Platform.isWindows ? 'cmd' : 'sh',
        [Platform.isWindows ? '/c' : '-c', installCmd]
    );

    if (result.exitCode != 0) {
      report.addError('安装失败: ${result.stderr}');
      report.addLog('安装详细输出: ${result.stdout}');
    } else {
      report.addLog('应用安装成功');
    }
  } catch (e) {
    report.addError('安装过程中出错: $e');
  }
}

Future<void> _runUnitTests(String projectRoot, TestReport report) async {
  try {
    report.addLog('开始运行单元测试...');

    final flutterPath = _findFlutterExecutable();
    final testCmd = '$flutterPath test';

    final result = await Process.run(
        Platform.isWindows ? 'cmd' : 'sh',
        [Platform.isWindows ? '/c' : '-c', testCmd],
        workingDirectory: projectRoot
    );

    if (result.exitCode != 0) {
      report.addError('单元测试失败: ${result.stderr}');
      report.addLog('单元测试详细输出: ${result.stdout}');
    } else {
      report.addLog('单元测试通过');

      // 解析测试结果
      final testOutput = result.stdout.toString();
      final passed = RegExp(r'All tests passed!').hasMatch(testOutput);
      final testCount = RegExp(r'(\d+) tests? passed').firstMatch(testOutput)?.group(1);

      report.addTestMetric('unitTestsPassed', passed);
      report.addTestMetric('unitTestsCount', testCount != null ? int.parse(testCount) : 0);
    }
  } catch (e) {
    report.addError('单元测试过程中出错: $e');
  }
}

Future<void> _runIntegrationTests(String projectRoot, TestReport report) async {
  try {
    report.addLog('开始运行集成测试...');

    final flutterPath = _findFlutterExecutable();
    final testCmd = '$flutterPath test integration_test';

    final result = await Process.run(
        Platform.isWindows ? 'cmd' : 'sh',
        [Platform.isWindows ? '/c' : '-c', testCmd],
        workingDirectory: projectRoot
    );

    if (result.exitCode != 0) {
      report.addError('集成测试失败: ${result.stderr}');
      report.addLog('集成测试详细输出: ${result.stdout}');
    } else {
      report.addLog('集成测试通过');

      // 解析测试结果
      final testOutput = result.stdout.toString();
      final passed = RegExp(r'All tests passed!').hasMatch(testOutput);
      final testCount = RegExp(r'(\d+) tests? passed').firstMatch(testOutput)?.group(1);

      report.addTestMetric('integrationTestsPassed', passed);
      report.addTestMetric('integrationTestsCount', testCount != null ? int.parse(testCount) : 0);
    }
  } catch (e) {
    report.addError('集成测试过程中出错: $e');
  }
}

Future<void> _runPerformanceTests(String packageName, String projectRoot, String? deviceId, TestReport report) async {
  try {
    report.addLog('开始性能测试...');

    final flutterPath = _findFlutterExecutable();
    final perfCmd = '$flutterPath drive --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart';

    final result = await Process.run(
        Platform.isWindows ? 'cmd' : 'sh',
        [Platform.isWindows ? '/c' : '-c', perfCmd],
        workingDirectory: projectRoot
    );

    if (result.exitCode == 0) {
      final lines = result.stdout.toString().split('\n');
      for (final line in lines) {
        if (line.contains('[PERF]')) {
          final perfData = line.replaceFirst('[PERF]', '').trim();
          report.addLog('性能数据: $perfData');

          // 解析性能指标
          final metrics = _parsePerformanceMetrics(perfData);
          metrics.forEach((key, value) => report.addTestMetric(key, value));

          // 检查性能问题
          if (perfData.contains('jank')) {
            report.addPerformanceIssue('检测到卡顿: $perfData');
          }
          if (perfData.contains('memory') && perfData.contains('MB')) {
            final memoryValue = double.tryParse(perfData.split(' ')[1]);
            if (memoryValue != null && memoryValue > 200) {
              report.addPerformanceIssue('内存使用过高: $perfData');
            }
          }
        }
      }
    } else {
      report.addError('性能测试失败: ${result.stderr}');
      report.addLog('性能测试详细输出: ${result.stdout}');
    }
  } catch (e) {
    report.addError('性能测试过程中出错: $e');
  }
}

Map<String, dynamic> _parsePerformanceMetrics(String perfData) {
  final metrics = <String, dynamic>{};

  try {
    // 示例: "帧率: 60 fps, 内存: 120 MB"
    final parts = perfData.split(',');
    for (final part in parts) {
      final keyValue = part.split(':');
      if (keyValue.length == 2) {
        final key = keyValue[0].trim();
        final value = keyValue[1].trim();

        // 尝试解析数值
        final numericValue = double.tryParse(value.split(' ')[0]);
        if (numericValue != null) {
          metrics[key] = numericValue;
        } else {
          metrics[key] = value;
        }
      }
    }
  } catch (e) {
    print('解析性能指标失败: $e');
  }

  return metrics;
}

Future<void> _runMonkeyTest(String packageName, String? deviceId, TestReport report) async {
  try {
    report.addLog('开始Monkey测试...');

    // 检查设备连接
    final devicesResult = await Process.run('adb', ['devices']);
    if (!devicesResult.stdout.toString().contains('device')) {
      report.addError('未检测到连接的设备');
      report.addLog('设备列表: ${devicesResult.stdout}');
      return;
    }

    // 检查应用是否安装
    final checkCmd = deviceId != null
        ? ['-s', deviceId, 'shell', 'pm', 'list', 'packages', packageName]
        : ['shell', 'pm', 'list', 'packages', packageName];

    final checkResult = await Process.run('adb', checkCmd);
    if (!checkResult.stdout.toString().contains(packageName)) {
      report.addError('应用未安装，无法进行Monkey测试');
      return;
    }

    // 运行Monkey测试
    final monkeyCmd = deviceId != null
        ? ['-s', deviceId, 'shell', 'monkey', '-p', packageName,
      '--throttle', '100', '--ignore-crashes', '--ignore-timeouts',
      '--ignore-security-exceptions', '--monitor-native-crashes',
      '--pct-touch', '70', '--pct-motion', '20', '--pct-trackball', '5', '--pct-nav', '5', '10000']
        : ['shell', 'monkey', '-p', packageName,
      '--throttle', '100', '--ignore-crashes', '--ignore-timeouts',
      '--ignore-security-exceptions', '--monitor-native-crashes',
      '--pct-touch', '70', '--pct-motion', '20', '--pct-trackball', '5', '--pct-nav', '5', '10000'];

    final result = await Process.run('adb', monkeyCmd);

    if (result.exitCode != 0) {
      report.addError('Monkey测试失败: ${result.stderr}');
      report.addLog('Monkey测试详细输出: ${result.stdout}');
    } else {
      report.addLog('Monkey测试完成');

      // 检查崩溃日志
      final crashLogs = await _checkCrashLogs(packageName, deviceId);
      if (crashLogs.isNotEmpty) {
        report.addError('检测到崩溃: $crashLogs');
      }
    }
  } catch (e) {
    report.addError('Monkey测试过程中出错: $e');
  }
}

Future<void> _runCustomTests(String packageName, String? deviceId, TestReport report) async {
  try {
    report.addLog('开始自定义功能测试...');

    // 测试1: 应用启动时间
    await _testAppLaunchTime(packageName, deviceId, report);

    // 测试2: 关键功能路径
    await _testCriticalPath(packageName, deviceId, report);

    // 测试3: 网络请求
    await _testNetworkRequests(packageName, deviceId, report);

    // 测试4: 数据库操作
    await _testDatabaseOperations(packageName, deviceId, report);
  } catch (e) {
    report.addError('自定义功能测试过程中出错: $e');
  }
}

Future<void> _testAppLaunchTime(String packageName, String? deviceId, TestReport report) async {
  try {
    report.addLog('测试应用启动时间...');

    final launchCmd = deviceId != null
        ? ['-s', deviceId, 'shell', 'am', 'start', '-W', '-n', '$packageName/.MainActivity']
        : ['shell', 'am', 'start', '-W', '-n', '$packageName/.MainActivity'];

    final result = await Process.run('adb', launchCmd);

    if (result.exitCode == 0) {
      final output = result.stdout.toString();
      final totalTime = RegExp(r'TotalTime: (\d+)').firstMatch(output)?.group(1);

      if (totalTime != null) {
        final timeMs = int.parse(totalTime);
        report.addTestMetric('appLaunchTime', timeMs);
        report.addLog('应用启动时间: ${timeMs}ms');

        if (timeMs > 1000) {
          report.addPerformanceIssue('应用启动时间过长: ${timeMs}ms');
        }
      }
    }
  } catch (e) {
    report.addError('启动时间测试失败: $e');
  }
}

Future<void> _testCriticalPath(String packageName, String? deviceId, TestReport report) async {
  try {
    report.addLog('测试关键功能路径...');

    // 模拟用户登录流程
    await _simulateLogin(packageName, deviceId, report);

    // 模拟主要功能操作
    await _simulateMainFeatures(packageName, deviceId, report);

  } catch (e) {
    report.addError('关键功能路径测试失败: $e');
  }
}
// 检查崩溃日志
Future<String> _checkCrashLogs(String packageName, String? deviceId) async {
  try {
    // report.addLog('检查崩溃日志...');

    // 构造ADB命令
    final logcatCmd = deviceId != null
        ? ['-s', deviceId, 'logcat', '-d', '-s', 'AndroidRuntime:E', '*:S']
        : ['logcat', '-d', '-s', 'AndroidRuntime:E', '*:S'];

    // 执行命令
    final result = await Process.run('adb', logcatCmd);

    if (result.exitCode == 0) {
      final output = result.stdout.toString();

      if (output.isNotEmpty) {
        // 解析崩溃日志
        final crashPattern = RegExp(r'FATAL EXCEPTION.*?\n(.*?)\n', dotAll: true);
        final matches = crashPattern.allMatches(output);

        if (matches.isNotEmpty) {
          final crashReports = matches.map((m) => m.group(0)!.trim()).toList();
          return crashReports.join('\n\n');
        }
      }
      return '未检测到崩溃日志';
    } else {
      return '获取崩溃日志失败: ${result.stderr}';
    }
  } catch (e) {
    return '获取崩溃日志时出错: $e';
  }
}
// 自定义功能测试实现

// 2. 关键功能路径测试

// 2.1 模拟登录流程
Future<void> _simulateLogin(String packageName, String? deviceId, TestReport report) async {
  try {
    report.addLog('模拟登录流程...');

    // 启动应用
    await _runAdbCommand(deviceId, ['shell', 'am', 'start', '-n', '$packageName/.MainActivity']);
    await Future.delayed(Duration(seconds: 2));

    // 输入用户名
    await _runAdbCommand(deviceId, ['shell', 'input', 'text', 'testuser']);
    await Future.delayed(Duration(milliseconds: 500));

    // 输入密码
    await _runAdbCommand(deviceId, ['shell', 'input', 'text', 'testpassword']);
    await Future.delayed(Duration(milliseconds: 500));

    // 点击登录按钮 (假设位置在500,500)
    await _runAdbCommand(deviceId, ['shell', 'input', 'tap', '500', '500']);
    await Future.delayed(Duration(seconds: 3));

    // 检查登录状态
    final result = await _runAdbCommand(deviceId, ['shell', 'dumpsys', 'activity', 'top']);
    if (result.stdout.toString().contains('MainActivity')) {
      report.addLog('登录流程测试通过');
      report.addTestMetric('loginTestPassed', true);
    } else {
      report.addError('登录流程测试失败');
      report.addTestMetric('loginTestPassed', false);
    }
  } catch (e) {
    report.addError('登录流程测试失败: $e');
  }
}

// 2.2 模拟主要功能操作
Future<void> _simulateMainFeatures(String packageName, String? deviceId, TestReport report) async {
  try {
    report.addLog('模拟主要功能操作...');

    // 导航到功能A
    await _runAdbCommand(deviceId, ['shell', 'input', 'tap', '300', '300']); // 点击功能A按钮
    await Future.delayed(Duration(seconds: 1));

    // 执行功能A操作
    await _runAdbCommand(deviceId, ['shell', 'input', 'text', '测试数据']);
    await Future.delayed(Duration(milliseconds: 500));
    await _runAdbCommand(deviceId, ['shell', 'input', 'tap', '400', '400']); // 提交

    // 返回主页
    await _runAdbCommand(deviceId, ['shell', 'input', 'keyevent', 'KEYCODE_BACK']);
    await Future.delayed(Duration(seconds: 1));

    // 导航到功能B
    await _runAdbCommand(deviceId, ['shell', 'input', 'tap', '300', '400']); // 点击功能B按钮
    await Future.delayed(Duration(seconds: 1));

    // 执行功能B操作
    await _runAdbCommand(deviceId, ['shell', 'input', 'swipe', '500', '1000', '500', '500', '500']); // 滑动
    await Future.delayed(Duration(milliseconds: 500));
    await _runAdbCommand(deviceId, ['shell', 'input', 'tap', '500', '600']); // 选择项目

    report.addLog('主要功能操作测试完成');
    report.addTestMetric('mainFeaturesTestPassed', true);
  } catch (e) {
    report.addError('主要功能操作测试失败: $e');
    report.addTestMetric('mainFeaturesTestPassed', false);
  }
}

// 2.3 模拟支付流程
Future<void> _simulatePayment(String packageName, String? deviceId, TestReport report) async {
  try {
    report.addLog('模拟支付流程...');

    // 导航到支付页面
    await _runAdbCommand(deviceId, ['shell', 'input', 'tap', '700', '300']); // 点击支付按钮
    await Future.delayed(Duration(seconds: 1));

    // 输入支付金额
    await _runAdbCommand(deviceId, ['shell', 'input', 'text', '100']);
    await Future.delayed(Duration(milliseconds: 500));

    // 选择支付方式
    await _runAdbCommand(deviceId, ['shell', 'input', 'tap', '400', '700']); // 选择支付方式
    await Future.delayed(Duration(seconds: 1));

    // 确认支付
    await _runAdbCommand(deviceId, ['shell', 'input', 'tap', '500', '800']); // 确认支付按钮
    await Future.delayed(Duration(seconds: 3));

    // 检查支付结果
    final result = await _runAdbCommand(deviceId, ['shell', 'dumpsys', 'activity', 'top']);
    if (result.stdout.toString().contains('PaymentSuccess')) {
      report.addLog('支付流程测试通过');
      report.addTestMetric('paymentTestPassed', true);
    } else {
      report.addError('支付流程测试失败');
      report.addTestMetric('paymentTestPassed', false);
    }
  } catch (e) {
    report.addError('支付流程测试失败: $e');
    report.addTestMetric('paymentTestPassed', false);
  }
}

// 3. 网络请求测试
Future<void> _testNetworkRequests(String packageName, String? deviceId, TestReport report) async {
  try {
    report.addLog('测试网络请求...');

    // 启动应用
    await _runAdbCommand(deviceId, ['shell', 'am', 'start', '-n', '$packageName/.MainActivity']);
    await Future.delayed(Duration(seconds: 2));

    // 触发网络请求
    await _runAdbCommand(deviceId, ['shell', 'input', 'tap', '600', '300']); // 点击刷新按钮

    // 等待网络响应
    await Future.delayed(Duration(seconds: 5));

    // 检查网络请求结果
    final result = await _runAdbCommand(deviceId, ['logcat', '-d', '-s', 'Network']);
    if (result.stdout.toString().contains('200 OK')) {
      report.addLog('网络请求测试通过');
      report.addTestMetric('networkTestPassed', true);
    } else {
      report.addError('网络请求测试失败');
      report.addTestMetric('networkTestPassed', false);
    }
  } catch (e) {
    report.addError('网络请求测试失败: $e');
    report.addTestMetric('networkTestPassed', false);
  }
}

// 4. 数据库操作测试
Future<void> _testDatabaseOperations(String packageName, String? deviceId, TestReport report) async {
  try {
    report.addLog('测试数据库操作...');

    // 启动应用
    await _runAdbCommand(deviceId, ['shell', 'am', 'start', '-n', '$packageName/.MainActivity']);
    await Future.delayed(Duration(seconds: 2));

    // 创建测试数据
    await _runAdbCommand(deviceId, ['shell', 'input', 'tap', '700', '400']); // 点击添加数据按钮
    await Future.delayed(Duration(seconds: 1));
    await _runAdbCommand(deviceId, ['shell', 'input', 'text', '测试数据']);
    await Future.delayed(Duration(milliseconds: 500));
    await _runAdbCommand(deviceId, ['shell', 'input', 'tap', '500', '600']); // 保存

    // 查询数据
    await Future.delayed(Duration(seconds: 1));
    await _runAdbCommand(deviceId, ['shell', 'input', 'tap', '700', '500']); // 点击查询按钮

    // 检查数据是否存在
    await Future.delayed(Duration(seconds: 2));
    final result = await _runAdbCommand(deviceId, ['shell', 'dumpsys', 'activity', 'top']);
    if (result.stdout.toString().contains('测试数据')) {
      report.addLog('数据库操作测试通过');
      report.addTestMetric('databaseTestPassed', true);
    } else {
      report.addError('数据库操作测试失败');
      report.addTestMetric('databaseTestPassed', false);
    }
  } catch (e) {
    report.addError('数据库操作测试失败: $e');
    report.addTestMetric('databaseTestPassed', false);
  }
}

// 5. UI响应测试
Future<void> _testUIResponsiveness(String packageName, String? deviceId, TestReport report) async {
  try {
    report.addLog('测试UI响应性...');

    // 启动应用
    await _runAdbCommand(deviceId, ['shell', 'am', 'start', '-n', '$packageName/.MainActivity']);
    await Future.delayed(Duration(seconds: 2));

    // 记录开始时间
    final startTime = DateTime.now();

    // 执行一系列UI操作
    for (int i = 0; i < 10; i++) {
      await _runAdbCommand(deviceId, ['shell', 'input', 'tap', '${300 + i * 50}', '300']);
      await Future.delayed(Duration(milliseconds: 100));
    }

    // 计算响应时间
    final endTime = DateTime.now();
    final responseTime = endTime.difference(startTime).inMilliseconds;

    report.addLog('UI响应时间: ${responseTime}ms');
    report.addTestMetric('uiResponseTime', responseTime);

    if (responseTime > 500) {
      report.addPerformanceIssue('UI响应时间过长: ${responseTime}ms');
    }
  } catch (e) {
    report.addError('UI响应测试失败: $e');
  }
}

// 辅助方法：执行ADB命令
Future<ProcessResult> _runAdbCommand(String? deviceId, List<String> command) async {
  final args = deviceId != null ? ['-s', deviceId, ...command] : command;
  return await Process.run('adb', args);
}


Future<void> _saveReport(TestReport report, String outputFile) async {
  try {
    final file = File(outputFile);
    await file.writeAsString(jsonEncode(report.toJson()));
  } catch (e) {
    print('无法保存报告: $e');
  }
}

Future<void> _uninstallApp(String packageName, String? deviceId) async {
  try {
    final uninstallCmd = deviceId != null
        ? ['-s', deviceId, 'uninstall', packageName]
        : ['uninstall', packageName];

    await Process.run('adb', uninstallCmd);
  } catch (e) {
    print('卸载应用失败: $e');
  }
}

void _generateTestSummary(TestReport report) {
  print('\n===== 测试总结 =====');
  print('总测试项: ${report.testMetrics.length}');

  if (report.errors.isNotEmpty) {
    print('\n发现的问题:');
    report.errors.take(5).forEach(print);
    if (report.errors.length > 5) print('...还有${report.errors.length - 5}个问题');
  }

  if (report.performanceIssues.isNotEmpty) {
    print('\n性能问题:');
    report.performanceIssues.take(3).forEach(print);
    if (report.performanceIssues.length > 3) print('...还有${report.performanceIssues.length - 3}个问题');
  }

  if (report.testMetrics.isNotEmpty) {
    print('\n关键指标:');
    report.testMetrics.forEach((key, value) {
      print('$key: $value');
    });
  }

  print('\n测试状态: ${report.errors.isEmpty ? "通过" : "失败"}');
  print('=' * 30);
}
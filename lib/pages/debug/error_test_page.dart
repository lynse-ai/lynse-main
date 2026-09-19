// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:dting/utils/error_utils.dart';
// import 'package:dting/service/error_handler_service.dart';
// import 'package:dting/utils/zone_test_utils.dart';
// import 'package:get/get.dart';

// /// 错误处理测试页面
// /// 用于测试和演示错误处理功能
// class ErrorTestPage extends StatefulWidget {
//   const ErrorTestPage({Key? key}) : super(key: key);

//   @override
//   State<ErrorTestPage> createState() => _ErrorTestPageState();
// }

// class _ErrorTestPageState extends State<ErrorTestPage> {
//   final List<String> _logs = [];

//   void _addLog(String message) {
//     setState(() {
//       _logs.insert(
//         0,
//         '${DateTime.now().toString().substring(11, 19)}: $message',
//       );
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('错误处理测试'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.bug_report),
//             onPressed: () => ErrorUtils.showLogViewer(context),
//             tooltip: '查看错误日志',
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // 测试按钮区域
//           Expanded(
//             flex: 2,
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: GridView.count(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 10,
//                 mainAxisSpacing: 10,
//                 childAspectRatio: 2.5,
//                 children: [
//                   _buildTestButton('触发Flutter错误', Colors.red, () {
//                     _addLog('触发Flutter框架错误');
//                     ErrorTestUtils.triggerFlutterError();
//                   }),
//                   _buildTestButton('触发异步错误', Colors.orange, () {
//                     _addLog('触发异步错误');
//                     ErrorTestUtils.triggerAsyncError();
//                   }),
//                   _buildTestButton('触发空指针错误', Colors.purple, () {
//                     _addLog('触发空指针错误');
//                     try {
//                       ErrorTestUtils.triggerNullPointerError();
//                     } catch (e, s) {
//                       ErrorUtils.reportError(
//                         error: e,
//                         stackTrace: s,
//                         context: '测试空指针错误',
//                       );
//                     }
//                   }),
//                   _buildTestButton('网络错误测试', Colors.blue, () async {
//                     _addLog('报告网络错误');
//                     await ErrorTestUtils.triggerNetworkError();
//                   }),
//                   _buildTestButton('业务错误测试', Colors.green, () async {
//                     _addLog('报告业务逻辑错误');
//                     await ErrorTestUtils.triggerBusinessError();
//                   }),
//                   _buildTestButton('自定义错误', Colors.teal, () async {
//                     _addLog('报告自定义错误');
//                     await ErrorUtils.reportError(
//                       error: '这是一个自定义测试错误',
//                       stackTrace: StackTrace.current,
//                       context: '错误测试页面',
//                       extraInfo: {
//                         'testType': 'custom',
//                         'userId': 'test_user',
//                         'pageRoute': '/error_test',
//                       },
//                     );
//                   }),
//                 ],
//               ),
//             ),
//           ),

//           // 分隔线
//           const Divider(),

//           // ANR配置区域
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0),
//             child: Column(
//               children: [
//                 const Text(
//                   'ANR检测配置',
//                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () {
//                           final isEnabled =
//                               ErrorHandlerService
//                                   .instance
//                                   .isAnrDetectionEnabled;
//                           ErrorHandlerService.instance.setAnrDetectionEnabled(
//                             !isEnabled,
//                           );
//                           _addLog('ANR检测已${!isEnabled ? "启用" : "禁用"}');
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text(
//                                 'ANR检测已${!isEnabled ? "启用" : "禁用"}',
//                               ),
//                             ),
//                           );
//                         },
//                         icon: const Icon(Icons.monitor_heart),
//                         label: const Text('切换ANR检测'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.purple,
//                           foregroundColor: Colors.white,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () => _showAnrConfigDialog(context),
//                         icon: const Icon(Icons.settings),
//                         label: const Text('配置ANR参数'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.indigo,
//                           foregroundColor: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () {
//                           _addLog('开始测试主线程阻塞（10秒）...');
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             const SnackBar(content: Text('主线程将阻塞10秒，测试ANR检测')),
//                           );
//                           // 阻塞主线程10秒来测试ANR检测
//                           final stopwatch = Stopwatch()..start();
//                           while (stopwatch.elapsedMilliseconds < 10000) {
//                             // 空循环阻塞主线程
//                           }
//                           _addLog('主线程阻塞测试完成');
//                         },
//                         icon: const Icon(Icons.block),
//                         label: const Text('测试主线程阻塞'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.red,
//                           foregroundColor: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () async {
//                           _addLog('开始测试错误处理服务...');

//                           try {
//                             // 1. 测试手动报告错误
//                             await ErrorHandlerService.reportError(
//                               error: '这是一个测试错误',
//                               stackTrace: StackTrace.current,
//                               context: '错误处理测试',
//                               extraInfo: {
//                                 'testType': 'manual_test',
//                                 'timestamp': DateTime.now().toIso8601String(),
//                               },
//                             );
//                             _addLog('✓ 手动错误报告测试完成');

//                             // 2. 检查日志文件
//                             final logFilePath =
//                                 ErrorHandlerService.instance.logFilePath;
//                             final logFile = File(logFilePath);

//                             if (await logFile.exists()) {
//                               final content = await logFile.readAsString();
//                               _addLog('✓ 日志文件创建成功');
//                               _addLog('日志文件大小: ${content.length} 字符');

//                               // 显示日志文件路径
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(content: Text('日志文件: $logFilePath')),
//                               );
//                             } else {
//                               _addLog('✗ 日志文件未创建');
//                             }
//                           } catch (e, s) {
//                             _addLog('✗ 测试过程中发生错误: $e');
//                             print('错误堆栈: $s');
//                           }
//                         },
//                         icon: const Icon(Icons.bug_report),
//                         label: const Text('测试错误处理'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.teal,
//                           foregroundColor: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 10),

//           // Zone测试区域
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0),
//             child: Column(
//               children: [
//                 const Text(
//                   'Zone测试',
//                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () {
//                           ZoneTestUtils.checkZoneConfiguration();
//                           _addLog('Zone配置检查完成');
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             const SnackBar(
//                               content: Text('Zone配置检查完成，请查看控制台输出'),
//                             ),
//                           );
//                         },
//                         icon: const Icon(Icons.settings_applications),
//                         label: const Text('检查Zone配置'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.cyan,
//                           foregroundColor: Colors.white,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () {
//                           ZoneTestUtils.verifyFlutterBindingZone();
//                           _addLog('Flutter绑定Zone验证完成');
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             const SnackBar(content: Text('Flutter绑定Zone验证完成')),
//                           );
//                         },
//                         icon: const Icon(Icons.verified),
//                         label: const Text('验证绑定Zone'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.deepPurple,
//                           foregroundColor: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 10),

//           // 工具按钮区域
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16.0),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     onPressed: () => ErrorUtils.showLogViewer(context),
//                     icon: const Icon(Icons.folder_open),
//                     label: const Text('查看日志'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.blue,
//                       foregroundColor: Colors.white,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     onPressed: () async {
//                       await ErrorUtils.cleanOldLogs();
//                       _addLog('已清理旧日志文件');
//                       ScaffoldMessenger.of(
//                         context,
//                       ).showSnackBar(const SnackBar(content: Text('旧日志文件已清理')));
//                     },
//                     icon: const Icon(Icons.cleaning_services),
//                     label: const Text('清理日志'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.orange,
//                       foregroundColor: Colors.white,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 10),

//           // 日志显示区域
//           Expanded(
//             flex: 1,
//             child: Container(
//               margin: const EdgeInsets.all(16.0),
//               padding: const EdgeInsets.all(12.0),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(8.0),
//                 border: Border.all(color: Colors.grey.shade300),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       const Icon(Icons.terminal, size: 16),
//                       const SizedBox(width: 8),
//                       const Text(
//                         '操作日志',
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       const Spacer(),
//                       TextButton(
//                         onPressed: () {
//                           setState(() {
//                             _logs.clear();
//                           });
//                         },
//                         child: const Text('清空'),
//                       ),
//                     ],
//                   ),
//                   const Divider(),
//                   Expanded(
//                     child:
//                         _logs.isEmpty
//                             ? const Center(
//                               child: Text(
//                                 '点击上方按钮测试错误处理功能',
//                                 style: TextStyle(color: Colors.grey),
//                               ),
//                             )
//                             : ListView.builder(
//                               itemCount: _logs.length,
//                               itemBuilder: (context, index) {
//                                 return Padding(
//                                   padding: const EdgeInsets.symmetric(
//                                     vertical: 2.0,
//                                   ),
//                                   child: Text(
//                                     _logs[index],
//                                     style: const TextStyle(
//                                       fontFamily: 'monospace',
//                                       fontSize: 12,
//                                     ),
//                                   ),
//                                 );
//                               },
//                             ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTestButton(String title, Color color, VoidCallback onPressed) {
//     return ElevatedButton(
//       onPressed: onPressed,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: color,
//         foregroundColor: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       ),
//       child: Text(
//         title,
//         style: const TextStyle(fontSize: 12),
//         textAlign: TextAlign.center,
//       ),
//     );
//   }

//   /// 显示ANR配置对话框
//   void _showAnrConfigDialog(BuildContext context) {
//     final thresholdController = TextEditingController(
//       text: ErrorHandlerService.instance.anrThresholdSeconds.toString(),
//     );
//     final intervalController = TextEditingController(
//       text: ErrorHandlerService.instance.anrCheckIntervalSeconds.toString(),
//     );

//     showDialog(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             title: const Text('ANR检测配置'),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Text(
//                   'ANR检测基于主线程响应性测试，不依赖用户交互',
//                   style: TextStyle(fontSize: 12, color: Colors.grey),
//                 ),
//                 const SizedBox(height: 16),
//                 TextField(
//                   controller: thresholdController,
//                   decoration: const InputDecoration(
//                     labelText: 'ANR阈值（秒）',
//                     hintText: '主线程无响应超过此时间认为发生ANR',
//                   ),
//                   keyboardType: TextInputType.number,
//                 ),
//                 const SizedBox(height: 16),
//                 TextField(
//                   controller: intervalController,
//                   decoration: const InputDecoration(
//                     labelText: '检测间隔（秒）',
//                     hintText: '主线程响应性测试的时间间隔',
//                   ),
//                   keyboardType: TextInputType.number,
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 child: const Text('取消'),
//               ),
//               TextButton(
//                 onPressed: () {
//                   final threshold = int.tryParse(thresholdController.text) ?? 5;
//                   final interval = int.tryParse(intervalController.text) ?? 1;

//                   ErrorHandlerService.instance.setAnrThreshold(threshold);
//                   ErrorHandlerService.instance.setAnrCheckInterval(interval);

//                   Navigator.of(context).pop();
//                   _addLog('ANR配置已更新: 阈值${threshold}秒, 间隔${interval}秒');
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(
//                         'ANR配置已更新: 阈值${threshold}秒, 间隔${interval}秒',
//                       ),
//                     ),
//                   );
//                 },
//                 child: const Text('确定'),
//               ),
//             ],
//           ),
//     );
//   }
// }

// /// 错误处理测试页面控制器
// class ErrorTestController extends GetxController {
//   /// 导航到错误测试页面
//   static void navigateToErrorTest() {
//     Get.to(() => const ErrorTestPage());
//   }

//   /// 显示错误处理信息对话框
//   static void showErrorHandlingInfo(BuildContext context) {
//     showDialog(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             title: const Text('错误处理系统'),
//             content: const SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(
//                     '本应用集成了完整的错误处理系统：',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   SizedBox(height: 10),
//                   Text('✅ 自动捕获Flutter框架错误'),
//                   Text('✅ 自动捕获异步错误'),
//                   Text('✅ 自动捕获平台错误'),
//                   Text('✅ ANR（应用无响应）检测'),
//                   Text('✅ 错误日志本地存储'),
//                   Text('✅ 日志文件自动管理'),
//                   Text('✅ 可视化日志查看器'),
//                   SizedBox(height: 10),
//                   Text(
//                     '日志文件位置：',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   Text('应用文档目录/crash_logs/'),
//                   SizedBox(height: 10),
//                   Text('使用建议：', style: TextStyle(fontWeight: FontWeight.bold)),
//                   Text('• 定期查看错误日志'),
//                   Text('• 及时清理旧日志文件'),
//                   Text('• 在关键业务逻辑中添加错误报告'),
//                 ],
//               ),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.of(context).pop(),
//                 child: const Text('知道了'),
//               ),
//               TextButton(
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                   ErrorTestController.navigateToErrorTest();
//                 },
//                 child: const Text('测试功能'),
//               ),
//             ],
//           ),
//     );
//   }
// }

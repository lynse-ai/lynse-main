/// 助手版 Lynse 入口。
///
/// 无账号纯本地（第一版）：启动即进助手外壳。微信登录/支付等旧链路
/// 已随旧 UI 删除；硬件层在 shell binding 中按需初始化。
library;

import 'dart:async';
import 'dart:io';

import 'package:dting/config/config.dart';
import 'package:dting/core/hardware/newview/newview_probe_runner.dart';
import 'package:dting/core/services/device_session_controller.dart';
import 'package:dting/intl/messages_all.dart';
import 'package:dting/router/router.dart';
import 'package:dting/ui/theme.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/utils/local_sqldb.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!await LocalDataBase().init()) return;
  if (!await SqlDBHelper().initDb()) return;

  // 硬件层：默认走统一 LYNSE Hardware SDK；旧双适配器可用 --dart-define 回退。
  await DeviceSessionController.init().bootstrap();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());

  // Newview 裸协议探测台（联调用，不依赖厂商 AAR）。
  // 只有手机上存在 files/newview_probe.txt、或编译期带了 NEWVIEW_PROBE=1..4
  // 才会真的动；否则 maybeStart 读完计划立刻返回。
  // 延时是让首屏的定位/蓝牙授权弹窗先过掉，不然扫描会以权限失败收场。
  if (Platform.isAndroid && !Config.useSdkHardware) {
    Timer(const Duration(seconds: 8), NewviewProbeRunner.maybeStart);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '灵斯记',
      initialRoute: AppRouter.initialRoute,
      getPages: AppRouter.pages,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      translations: Messages(),
      supportedLocales: const [Locale('zh', 'CN')],
      locale: const Locale('zh', 'CN'),
      fallbackLocale: const Locale('zh', 'CN'),
      theme: AssistantTheme.light(),
      darkTheme: AssistantTheme.light(),
      themeMode: ThemeMode.light, // 助手版先只做浅色（OpenMUSE 基因是浅色画布）
    );
  }
}

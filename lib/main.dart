/// 助手版 Lynse 入口。
///
/// 无账号纯本地（第一版）：启动即进助手外壳。微信登录/支付等旧链路
/// 已随旧 UI 删除；硬件层在 shell binding 中按需初始化。
library;

import 'package:dting/core/services/device_session_controller.dart';
import 'package:dting/intl/messages_all.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';
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

  // 原生插件（Neview 通道）+ 硬件抽象层（双厂商适配器）
  NvEasyPlugin.init();
  DeviceSessionController.init().bootstrap();

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
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Lynse',
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

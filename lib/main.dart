import 'package:dting/config/config.dart';
import 'package:dting/controller/device_session_controller.dart';
import 'package:dting/intl/messages_all.dart';
import 'package:dting/pages/home/home_index/home_observer.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/styles/theme.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/utils/local_sqldb.dart';
import 'package:dting/service/network_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluwx/fluwx.dart';
import 'package:get/get.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'router/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // load database
  if (!await _loadDatabase()) {
    return;
  }
  if (!await _loadSqlDB()) {
    return;
  }
  // await _requestAllPermissions();
  await _initWeChat();
  // load basic data
  _loadBasicController();
  // init plugin
  NvEasyPlugin.init();
  // init lynse hardware abstraction layer (双厂商适配器)
  DeviceSessionController.init().bootstrap();
  // 设置只允许竖屏方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // 全局设置沉浸式状态栏
  _systeUIMode();
  runApp(const MyApp());

  _doSetting();
}

_initWeChat() async {
  await Fluwx().registerApi(
    appId: Config.appId,
    universalLink: Config.universalLink,
  );
}

void _systeUIMode() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // 白天模式用dark，夜间模式用light
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
}

void _doSetting() {
  // loading setting
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 3000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.dark
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = ColorUtil.fromHexString("#FFFFFF")
    ..backgroundColor = ColorUtil.fromHexString("#161616")
    ..indicatorColor = ColorUtil.fromHexString("#FFFFFF")
    ..textColor = Colors.white
    ..userInteractions = false
    ..dismissOnTap = false
    ..maskType = EasyLoadingMaskType.clear
    ..maskColor = Colors.transparent;
}

Future<void> _loadBasicController() async {
  print('初始化全局的controller _loadBasicController');
  Get.lazyPut(() => DtingStore(), fenix: true);
  // 初始化服务
  Get.put(NetworkService());
  // Get.putAsync(() async => NetworkService().onInit());
}

Future<bool> _loadDatabase() {
  return LocalDataBase().init();
}

Future<bool> _loadSqlDB() {
  return SqlDBHelper().initDb();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: Size(375, 100),
      minTextAdapt: false,
      builder: (context, child) {
        return GetMaterialApp(
          title: '灵斯记',
          builder: (context, child) {
            // 语义色注入：所有 lynse 页面通过 context.lynse 取 token
            final semantic =
                Theme.of(context).brightness == Brightness.dark
                    ? LynseSemantic.dark
                    : LynseSemantic.light;
            return EasyLoading.init()(
              context,
              LynseInherited(
                semantic: semantic,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          initialRoute: AppRouter.initialRoute,
          // initialBinding: InitialBinding(),
          getPages: AppRouter.pages,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          translations: Messages(),
          navigatorObservers: [HomeRouteObserver()], // 添加自定义观察者
          supportedLocales: const [Locale('zh', 'CN')],
          locale: const Locale('zh', 'CN'),
          fallbackLocale: const Locale('zh', 'CN'),
          theme: LynseTheme.light(),
          darkTheme: LynseTheme.dark(),
          themeMode: ThemeMode.light, // TODO: 设置页加「外观」三选后改为动态
        );
      },
    );
  }
}

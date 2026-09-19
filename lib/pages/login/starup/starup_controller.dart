import 'dart:ui';
import 'package:dting/config/config.dart';
import 'package:dting/service/login_service.dart';
import 'package:dting/service/personal_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class StarupController extends GetxController {
  var appController = Get.find<DtingStore>();
  @override
  void onInit() {
    super.onInit(); 
    _setLanguage();
    isLoginStatus();
  }

  void isLoginStatus() {
    // 暂时跳过登录直进 lynse 新版首页（2026-09-18 临时需求，恢复登录时
    // 重新加上 kDebugMode 限制即可）
    if (Config.debugSkipLogin) {
      // 必须等首帧后再导航：build 过程中 Get.offNamed 会触发
      // "setState() or markNeedsBuild() called during build" 异常
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NavigationUtils.replaceHomeIndex();
      });
      return;
    }
    LoginService.isLoginStatus().then((val) {
      if (val) {
        //跳过登录直接去首页
        PersonalService.getCurrentUserLoginInfo().then((user) {
          if (user != null) {
            appController.userInfo.value = user;
            NavigationUtils.toHomeIndex();
          } else {
            NavigationUtils.toMobileLogIn();
          }
        });
      } else {
        //需要重新登录
        Future.delayed(const Duration(seconds: 2), () {
          NavigationUtils.toMobileLogIn();
        });
      }
    });
  }

  _setLanguage() {
    String? language = LocalDataBase().basicBox!.get("language");
    switch (language) {
      case "en_US":
        Get.updateLocale(const Locale("en", "US"));
        break;
      default:
        Get.updateLocale(const Locale("zh", "CN"));
        break;
    }
  }
}

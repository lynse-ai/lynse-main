import 'dart:async';

import 'package:dting/model/login_model/bind_phone_model.dart';
import 'package:dting/model/login_model/login_request_model.dart';
import 'package:dting/model/login_model/login_response_model.dart';
import 'package:dting/model/personal_model/userinfo_model.dart';
import 'package:dting/service/login_service.dart';
import 'package:dting/service/personal_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BindMobilePhoneController extends GetxController {
  var appController = Get.find<DtingStore>();

  var bindPhoneController = TextEditingController();
  var codeController = TextEditingController();
  var checkBindPhone = false.obs;
  var checkBindCode = false.obs;

  LoginResponsetModel? loginRespones;
  LoginRequestModel? loginRequest;
  //切换焦点
  final phoneFocusNode = FocusNode();
  final codeFocusNode = FocusNode();
  //================================登录轮播图===============================
  final List<String> images = [
    'assets/images_v3/login-bg3.png',
    'assets/images_v3/login-bg.png',
    'assets/images_v3/login-bg4.png',
    'assets/images_v3/login-bg2.png',
    'assets/images_v3/login-bg5.png',
  ];

  final pageController = PageController();
  var currentIndex = 0.obs;
  Timer? timer;
  //================================登录轮播图===============================
  @override
  void onInit() {
    super.onInit();
    loginRespones = (Get.arguments['loginRespones']);
    loginRequest = (Get.arguments['loginRequest']);
  }

  // void isAccountExist({
  //   required UserInfoModel userInfo,
  //   required LoginResponsetModel returnData,
  // }) {
  //   if (userInfo.password != null) {
  //     gotoNavigation(userInfo, returnData);
  //   } else {
  //     if (loginRequest != null) {
  //       NavigationUtils.toBindMobilePhoneWithSetPwd(
  //         loginRequest: loginRequest!,
  //         loginRespones: returnData,
  //       );
  //     }
  //   }
  // }

  void gotoNavigation(UserInfoModel userInfo, LoginResponsetModel returnData) {
    appController.userInfo.value = userInfo;
    var locale = Get.locale;
    var language = "${locale!.languageCode}-${locale.countryCode!}";
    LocalDataBase.setCache(
      language: language,
      lastLoginTime: DateTime.now().toString(),
      loginUserID: userInfo.id,
      token: returnData.token,
      wexinCode: loginRequest!.code,
      authType: loginRequest!.authType,
      appleToken: loginRequest!.identityToken,
    );
    // if (returnData.firstLogin != null && returnData.firstLogin!) {
    //   NavigationUtils.toHomePrompt();
    // } else {
      NavigationUtils.toHomeIndex();
    // }
  }

  void bindPhone() {
    String bindPhone = bindPhoneController.text;
    String smsCode = codeController.text;

    if (bindPhone.isNotEmpty && smsCode.isNotEmpty) {
      BindPhoneModel bind = BindPhoneModel(
        authType: loginRequest!.authType,
        username: bindPhone,
        thirdPartyId: loginRespones!.thirdPartyId!,
        captchaCode: smsCode,
      );
      LoginService.bindPhone(bind).then((val) {
        if (val != null) {
          if (val.data != null) {
            var returnData = LoginResponsetModel.fromJson(val.data);
            PersonalService.getCurrentUserLoginInfo().then((user) {
              if (user != null) {
                // isAccountExist(userInfo: user, returnData: returnData);
                gotoNavigation(user, returnData);
              }
            });
          } else {
            var message = val.msg;
            DialogHelper.showToastDialog(message);
          }
        }
      });
      // NavigationUtils.toMobileLogIn();
    } else {
      if (bindPhone.isEmpty) {
        checkBindPhone.value = true;
      }
      if (smsCode.isEmpty) {
        checkBindCode.value = true;
      }
    }
  }
}

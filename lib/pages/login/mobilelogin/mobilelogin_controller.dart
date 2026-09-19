import 'dart:async';

import 'package:dting/model/login_model/login_request_model.dart';
import 'package:dting/model/login_model/login_response_model.dart';
import 'package:dting/service/login_service.dart';
import 'package:dting/service/personal_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:fluwx/fluwx.dart';
import 'package:get/get.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class MobileLogInController extends GetxController {
  var appController = Get.find<DtingStore>();

  var checkPhone = false.obs;
  var checkCode = false.obs;

  var phoneController = TextEditingController();
  var codeController = TextEditingController(); //接收验证码
  final phoneFocusNode = FocusNode();
  final codeFocusNode = FocusNode();
  var agree = false.obs;
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

  Fluwx fluwx = Fluwx();
  var showAgreeDialog = false.obs;
  bool wxInstalled = false;

  @override
  Future<void> onInit() async {
    // TODO: implement onInit
    super.onInit();
    startAutoScroll();
    isFistStarUp();
    wxInstalled = await fluwx.isWeChatInstalled;

    // 注册微信回调监听（全局只注册一次）
    fluwx.addSubscriber((response) async {
      if (response is WeChatAuthResponse) {
        if (response.errCode == 0) {
          print("微信登录成功，code = ${response.code}");
          if (response.code != null && response.code!.isNotEmpty) {
            _handleLoginCode(response.code!);
          }
        } else {
          print("微信登录失败，错误码: ${response.errCode}");
          DialogHelper.showToastDialog("wechatFail");
        }
      }
    });
  }

  @override
  void onClose() {
    timer?.cancel();
    pageController.dispose();
    super.onClose();
  }

  void isFistStarUp() {
    var isAgree = LocalDataBase().basicBox!.get("agree");
    if (isAgree == null || isAgree == false) {
      showAgreeDialog.value = true;
    }
  }

  void startAutoScroll() {
    timer = Timer.periodic(Duration(seconds: 5), (_) {
      currentIndex.value = (currentIndex.value + 1) % images.length;
    });
  }

  Future<void> login() async {
    if (!agree.value) {
      DialogHelper.showToastDialog("agreeAgreement", duration: 2);
    } else {
      await EasyLoading.show();

      //sign up
      var signPhone = phoneController.text.trim();
      var signcode = codeController.text.trim();

      if (signPhone.isNotEmpty && signcode.isNotEmpty) {
        LoginRequestModel login = LoginRequestModel(
          authType: 'PHONE_CODE',
          username: signPhone,
          captchaCode: signcode,
        );

        try {
          final loginRsp = await LoginService.login(login);

          if (loginRsp == null) {
            DialogHelper.showToastDialog("loginFail");
            return;
          }

          if (loginRsp.code != 200 || loginRsp.data == null) {
            DialogHelper.showToastDialog(loginRsp.msg);
            await EasyLoading.dismiss();
            return;
          }

          final loginInfo = LoginResponsetModel.fromJson(loginRsp.data);
          if (loginInfo.token == null) {
            DialogHelper.showToastDialog(loginRsp.msg);
            return;
          }

          // 赋值用户信息
          final userInfo = await PersonalService.getCurrentUserLoginInfo();
          print('登录返回的用户信息: ${userInfo?.toJson()}');
          appController.userInfo.value = userInfo!;

          // 缓存
          final language =
              "${Get.locale!.languageCode}-${Get.locale!.countryCode}";
          LocalDataBase.setCache(
            language: language,
            lastLoginPhone: signPhone,
            lastLoginTime: DateTime.now().toString(),
            loginUserID: userInfo.id,
            token: loginInfo.token,
            authType: "PHONE_CODE",
            islogin: "true",
          );
        } catch (e) {
          print('====login error: $e');
        } finally {
          await EasyLoading.dismiss();
        }
        // 清空登录表单
        phoneController.text = "";
        codeController.text = "";

        NavigationUtils.replaceHomeIndex();
      } else {
        if (signPhone.isEmpty) {
          checkPhone.value = true;
        }
        if (signcode.isEmpty) {
          checkCode.value = true;
        }
      }

      await EasyLoading.dismiss();
    }
  }

  void clearCheckSign() {
    checkPhone.value = false;
    checkCode.value = false;
  }

  //微信登录
  Future<void> wexinRequest() async {
    if (!agree.value) {
      DialogHelper.showToastDialog("agreeAgreement");
      return;
    }
    var installWechat = await fluwx.isWeChatInstalled;
    if (!installWechat) {
      DialogHelper.showToastDialog("wechatLoginTip");
      return;
    }
    bool result = await fluwx.authBy(
      which: NormalAuth(
        scope: "snsapi_userinfo",
        state: "wechat_sdk_demo_test",
      ),
    );

    if (!result) {
      DialogHelper.showToastDialog("wechatFail");
    }
  }

  // 处理登录 code，调用后端接口
  Future<void> _handleLoginCode(String code) async {
    try {
      EasyLoading.show(status: "登录中...");
      LoginRequestModel login = LoginRequestModel(
        authType: 'WECHAT_JUMP',
        code: code,
      );
      await loginRequest(login);
      EasyLoading.dismiss();
      // 登录成功后做跳转等逻辑
      // NavigationUtils.toHomePage();
    } catch (e) {
      EasyLoading.dismiss();
      DialogHelper.showToastDialog("loginFail");
    }
  }

  // Apple 登录
  Future<void> appleLogin() async {
    if (agree.value) {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      var appleToken = credential.identityToken;
      if (appleToken != null && appleToken.isNotEmpty) {
        LoginRequestModel login = LoginRequestModel(
          authType: 'APPLE',
          identityToken: appleToken,
        );
        print("token: $appleToken");
        loginRequest(login);
      } else {
        DialogHelper.showToastDialog("loginFail");
      }
    } else {
      DialogHelper.showToastDialog("agreeAgreement", duration: 2);
    }
  }

  Future<void> loginRequest(LoginRequestModel loginRequest) async {
    try {
      final res = await LoginService.login(loginRequest);
      print("用户登录成功 $res");

      if (res?.code != 200 || res?.data == null) {
        DialogHelper.showToastDialog(res?.msg ?? "loginFail");
        return;
      }

      final loginResponse = LoginResponsetModel.fromJson(res!.data);

      // 需要绑定手机号
      if (loginResponse.needBind == true) {
        NavigationUtils.toBindMobilePhone(
          loginRespones: loginResponse,
          loginRequest: loginRequest,
        );
        return;
      }

      // 获取用户信息
      final user = await PersonalService.getCurrentUserLoginInfo();
      if (user == null) {
        DialogHelper.showToastDialog("loginFail");
        return;
      }

      print(
        '用户登录成功appController.userInfo.value = ${appController.userInfo.value}',
      );
      appController.userInfo.value = user;

      // 缓存用户数据
      final locale = Get.locale!;
      final language = "${locale.languageCode}-${locale.countryCode!}";
      LocalDataBase.setCache(
        language: language,
        lastLoginTime: DateTime.now().toString(),
        loginUserID: user.id,
        token: loginResponse.token,
        wexinCode: loginRequest.code,
        authType: loginRequest.authType,
        appleToken: loginRequest.identityToken,
      );

      // 跳转页面
      // if (loginResponse.firstLogin == true) {
      //   NavigationUtils.toHomePrompt();
      // } else {
      NavigationUtils.toHomeIndex();
      // }
    } catch (e, stack) {
      print("登录异常: $e\n$stack");
      DialogHelper.showToastDialog("loginFail");
    }
  }
}

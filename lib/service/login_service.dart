import 'package:dting/http/http_helper.dart';
import 'package:dting/model/baseapi/response_api_model.dart';
import 'package:dting/model/login_model/bind_phone_model.dart';
import 'package:dting/model/login_model/check_wechat_model.dart';
import 'package:dting/model/login_model/login_request_model.dart';
import 'package:dting/model/login_model/register_request_model.dart';
import 'package:dting/store/dting_store.dart';
import 'package:get/get.dart';

class LoginService {
  LoginService._();
  static Future<bool> isLoginStatus() async {
    bool returnData = false;

    await HttpHelper.post('/api/auth/isLogin').then((value) {
      if (value != null && value.data == true) {
        returnData = true;
      }
    });

    return returnData;
  }

  static Future<ResponseApiModel?> login(LoginRequestModel login) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/auth/login',
      data: {
        "authType": login.authType,
        "username": login.username,
        "password": login.password,
        "code": login.code,
        "state": login.state,
        "identityToken": login.identityToken,
        "captchaCode": login.captchaCode,
      },
    ).then((value) {
      if (value != null && value.data != null) {
        var tokenString = value.data["token"];
        print("login的 tokenString :$tokenString");
        if (tokenString != null) {
          HttpHelper.setToken(tokenString);
        }
        //记录是不是第一次登录
        var appController = Get.find<DtingStore>();
        var isfirstLogin = value.data["firstLogin"];

        appController.isfirstLogin.value = isfirstLogin;
      }

      returnData = value;
    });

    return returnData;
  }

  static Future<ResponseApiModel?> register(
    RegisterRequestModel register,
  ) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/auth/register',
      data: {
        "username": register.username,
        "password": register.password,
        "confirmPassword": register.confirmPassword,
        "captchaCode": register.captchaCode,
      },
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  //第三方登录
  static Future<ResponseApiModel?> render(String authType) async {
    ResponseApiModel? returnData;

    await HttpHelper.get(
      '/api/auth/render',
      queryParameters: {"authType": authType},
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  static Future<bool> logout() async {
    bool returnData = false;

    await HttpHelper.post('/api/auth/logout').then((value) {
      if (value?.code == 200) {
        returnData = true;
      }
    });

    return returnData;
  }

  //重置密码
  static Future<ResponseApiModel?> updatePwd(
    RegisterRequestModel register,
  ) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/auth/updatePwd',
      data: {
        "username": register.username,
        "password": register.password,
        "confirmPassword": register.confirmPassword,
        "captchaCode": register.captchaCode,
      },
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  //绑定手机
  static Future<ResponseApiModel?> bindPhone(BindPhoneModel bind) async {
    ResponseApiModel? returnData;

    await HttpHelper.get(
      '/api/auth/bind',
      queryParameters: {
        "authType": bind.authType,
        "username": bind.username,
        "captchaCode": bind.captchaCode,
        "thirdPartyId": bind.thirdPartyId,
      },
    ).then((value) {
      if (value != null && value.data != null) {
        var tokenString = value.data["token"];
        if (tokenString != null) {
          HttpHelper.setToken(tokenString);
        }
      }
      returnData = value;
    });

    return returnData;
  }

  //verifyWechat
  static Future<bool> check(CheckWechatModel check) async {
    bool returnData = false;

    await HttpHelper.get(
      '/api/auth/check',
      queryParameters: {
        "signature": check.signature,
        "timestamp": check.timestamp,
        "nonce": check.nonce,
        "echostr": check.echostr,
      },
    ).then((value) {
      if (value?.code == 200) {
        returnData = true;
      }
    });

    return returnData;
  }
}

import 'package:dting/model/login_model/login_request_model.dart';
import 'package:dting/model/login_model/login_response_model.dart';
import 'package:dting/model/personal_model/userinfo_model.dart';
import 'package:dting/service/personal_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SetPwdForBindMobilePhoneController extends GetxController {
  var appController = Get.find<DtingStore>();

  var bindPhoneController = TextEditingController();
  var codeController = TextEditingController();
  var checkBind = false.obs;

  var bindPhoneSetPwdController = TextEditingController();
  var bindPhoneConfirmPwdController = TextEditingController();

  var checkBindBySetPwd = false.obs;
  var checkBindBySetRePwd = false.obs;

  LoginRequestModel? loginRequest;
  LoginResponsetModel? loginRespones;
  @override
  void onInit() {
    super.onInit();
    loginRespones = (Get.arguments['loginRespones']);
    loginRequest = (Get.arguments['loginRequest']);
  }

  void gotoNavigation(UserInfoModel userInfo) {
    appController.userInfo.value = userInfo;
    var locale = Get.locale;
    var language = "${locale!.languageCode}-${locale.countryCode!}";
    LocalDataBase.setCache(
      language: language,
      lastLoginTime: DateTime.now().toString(),
      loginUserID: userInfo.id,
      token: loginRespones!.token,
      wexinCode: loginRequest!.code,
      authType: loginRequest!.authType,
      appleToken: loginRequest!.identityToken,
    );
    // if (loginRespones!.firstLogin != null && loginRespones!.firstLogin!) {
    //   NavigationUtils.toHomePrompt();
    // } else {
    NavigationUtils.toHomeIndex();
    // }
  }

  void setPwd() {
    String bindPhoneSetPwd = bindPhoneSetPwdController.text;
    String bindPhoneConfirmPwd = bindPhoneConfirmPwdController.text;

    if (bindPhoneSetPwd.isNotEmpty && bindPhoneConfirmPwd.isNotEmpty) {
      if (bindPhoneSetPwd != bindPhoneConfirmPwd) {
        checkBindBySetPwd.value = true;
        checkBindBySetRePwd.value = true;
      } else {
        checkBindBySetPwd.value = false;
        checkBindBySetRePwd.value = false;
        String setPwd = bindPhoneSetPwdController.text;
        UserInfoModel editUser = UserInfoModel(
          id: loginRespones!.customerId!,
          password: setPwd,
        );
        PersonalService.editUserInfo(
          editUser,
          confirmPwd: bindPhoneConfirmPwd,
        ).then((val) {
          if (val != null) {
            if (val.code == 200) {
              PersonalService.getCurrentUserLoginInfo().then((user) {
                if (user != null) {
                  appController.userInfo.value = user;
                  gotoNavigation(user);
                }
              });
            } else {
              var message = val.msg;
              DialogHelper.showToastDialog(message);
            }
          }
        });
      }
    } else {
      if (bindPhoneSetPwd.isEmpty) {
        checkBindBySetPwd.value = true;
      }
      if (bindPhoneConfirmPwd.isEmpty) {
        checkBindBySetRePwd.value = true;
      }
    }
  }
}

import 'package:dting/model/login_model/register_request_model.dart';
import 'package:dting/service/login_service.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ForgotPasswordController extends GetxController {
  var forgotPhoneController = TextEditingController();
  var forgotPwdController = TextEditingController();
  var forgotConfirmPwdController = TextEditingController();
  var codeController = TextEditingController(); //接受验证码

  var checkPhone = false.obs;
  var checkCode = false.obs;
  var checkPwd = false.obs;
  var checkRePwd = false.obs;

  @override
  void onInit() {
    super.onInit();
    //TODO
  }

  Future<void> definite() async {
    var forgotPhone = forgotPhoneController.text;
    var forgotPwd = forgotPwdController.text;
    var forgotConfirm = forgotConfirmPwdController.text;
    var forgotcode = codeController.text;

    if (forgotPhone.isNotEmpty &&
        forgotPwd.isNotEmpty &&
        forgotConfirm.isNotEmpty &&
        forgotcode.isNotEmpty) {
      if (forgotConfirm != forgotPwd) {
        checkPwd.value = true;
        checkRePwd.value = true;
      } else {
        checkPwd.value = false;
        checkRePwd.value = false;
        RegisterRequestModel forgot = RegisterRequestModel(
          username: forgotPhone,
          password: forgotPwd,
          confirmPassword: forgotConfirm,
          captchaCode: forgotcode,
        );
        var res = await LoginService.updatePwd(forgot);
        if (res != null) {
          if (res.code != 200) {
            var message = res.msg;
            DialogHelper.showToastDialog(message);
          } else {
            forgotPhoneController.text = "";
            forgotPwdController.text = "";
            forgotConfirmPwdController.text = "";
            codeController.text = "";
            NavigationUtils.toMobileLogIn();
          }
        } else {
          DialogHelper.showToastDialog("Successfully changed password");
        }
      }
    } else {
      if (forgotPhone.isEmpty) {
        checkPhone.value = true;
      }
      if (forgotPwd.isEmpty) {
        checkPwd.value = true;
      }
      if (forgotConfirm.isEmpty) {
        checkRePwd.value = true;
      }
      if (forgotcode.isEmpty) {
        checkCode.value = true;
      }
    }
  }
}

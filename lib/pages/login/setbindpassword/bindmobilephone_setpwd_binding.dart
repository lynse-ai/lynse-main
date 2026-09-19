import 'package:dting/pages/login/setbindpassword/bindmobilephone_setpwd_controller.dart';
import 'package:get/get.dart';

class SetPwdForBindMobilePhoneBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SetPwdForBindMobilePhoneController>(
      () => SetPwdForBindMobilePhoneController(),
    );
  }
}

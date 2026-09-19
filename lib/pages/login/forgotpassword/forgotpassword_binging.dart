import 'package:get/get.dart';

import 'forgotpassword_controller.dart'; 

class ForgotpasswordBinging extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ForgotPasswordController>(() => ForgotPasswordController());
  }
}

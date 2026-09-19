import 'package:get/get.dart';

import 'mobilelogin_controller.dart';

class MobileLogInBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MobileLogInController>(() => MobileLogInController());
  }
}

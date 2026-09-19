import 'package:get/get.dart';

import 'bindmobilephone_controller.dart';

class BindMobilePhoneBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BindMobilePhoneController>(() => BindMobilePhoneController());
  }
}

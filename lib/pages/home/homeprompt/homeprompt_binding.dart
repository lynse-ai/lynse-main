import 'package:get/get.dart';

import 'homeprompt_controller.dart';

class HomePromptBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomePromptController>(() => HomePromptController());
  }
}

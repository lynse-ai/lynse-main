import 'package:get/get.dart';

import 'help_controller.dart';

class HelpAndFeedBackBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HelpAndFeedBackController>(() => HelpAndFeedBackController());
  }
}

import 'package:dting/pages/device/prompt/prompt_list_controller.dart';
import 'package:get/get.dart';

class PromptListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PromptListController());
  }
}

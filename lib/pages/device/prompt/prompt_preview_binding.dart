import 'package:get/get.dart';
import 'package:dting/pages/device/prompt/prompt_preview_controller.dart';

class PromptPreviewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PromptPreviewController>(() => PromptPreviewController());
  }
}
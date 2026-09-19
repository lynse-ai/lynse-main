 
import 'package:dting/pages/device/menu/mind/mind_controller.dart';
import 'package:get/get.dart';

class MindBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MindController>(() => MindController());  
  }
}

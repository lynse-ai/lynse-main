import 'package:dting/pages/device/menu/concel/concel_controller.dart';
import 'package:get/get.dart';

class ConcelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ConcelController>(() => ConcelController()); 
  }
}

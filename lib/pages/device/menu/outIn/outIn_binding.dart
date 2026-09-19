 
import 'package:dting/pages/device/menu/outIn/outIn_controller.dart';
import 'package:get/get.dart';

class OutinBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<OutinController>(() => OutinController());  
  }
}

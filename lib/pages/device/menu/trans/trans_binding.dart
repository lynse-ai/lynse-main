import 'package:dting/pages/device/menu/trans/trans_controller.dart';
import 'package:get/get.dart';

class TransBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TransController>(() => TransController());   
  }
}

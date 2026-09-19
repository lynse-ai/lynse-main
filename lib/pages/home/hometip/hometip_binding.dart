import 'package:dting/pages/home/hometip/hometip_controller.dart';
import 'package:get/get.dart';

class HomeTipBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeTipController>(() => HomeTipController());
  }
}

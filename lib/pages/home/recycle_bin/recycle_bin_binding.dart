import 'package:dting/pages/home/recycle_bin/recycle_bin_controller.dart';
import 'package:get/get.dart';

class RecycleBinBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(RecycleBinController());
    // Get.lazyPut<RecycleBinController>(() => RecycleBinController());
  }
}

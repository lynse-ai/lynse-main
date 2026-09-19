import 'package:get/get.dart';

import 'search_device_controller.dart';

class SearchDeviceBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(SearchDeviceController());
  }
}

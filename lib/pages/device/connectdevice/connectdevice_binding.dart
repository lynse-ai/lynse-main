import 'package:get/get.dart';

import 'connectdevice_controller.dart';

class ConnectDeviceBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ConnectDeviceController());
  }
}

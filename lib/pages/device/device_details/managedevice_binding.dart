import 'package:get/get.dart';

import 'managedevice_controller.dart';
 

class ManageDeviceBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ManageDeviceController());
  }
}

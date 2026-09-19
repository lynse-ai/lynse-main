import 'package:get/get.dart';

import 'starup_controller.dart'; 

class StarupBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(StarupController());
  }
}

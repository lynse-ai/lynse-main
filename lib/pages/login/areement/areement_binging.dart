import 'package:get/get.dart';
import 'areement_controller.dart';

class AreementBinging extends Bindings {
  @override
  void dependencies() {
    Get.put(AreementController());
  }
}

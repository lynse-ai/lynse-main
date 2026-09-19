import 'package:dting/pages/device/bootstrapoperation/bootstrapoperation_controller.dart';
import 'package:get/get.dart';

class BootstrapOperationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BootstrapOperationController>(
      () => BootstrapOperationController(),
    );
  }
}

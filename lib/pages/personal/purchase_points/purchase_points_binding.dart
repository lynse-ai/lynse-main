import 'package:dting/pages/personal/purchase_points/purchase_points_controller.dart';
import 'package:get/get.dart';

class PurchasePointsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PurchasePointsController>(() => PurchasePointsController());
  }
}

import 'package:dting/pages/team/team_purchase_points/team_purchase_points_controller.dart';
import 'package:get/get.dart';

class TeamPurchasePointsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TeamPurchasePointsController>(
      () => TeamPurchasePointsController(),
    );
  }
}

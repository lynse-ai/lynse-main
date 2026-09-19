import 'package:get/get.dart';

import 'team_point_history_controller.dart';

class TeamPointHistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TeamPointHistoryController>(() => TeamPointHistoryController());
  }
}

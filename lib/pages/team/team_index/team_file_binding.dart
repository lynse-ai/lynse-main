import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:get/get.dart';

class TeamFileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TeamFileController>(() => TeamFileController());
  }
}

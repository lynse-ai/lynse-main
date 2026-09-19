import 'package:dting/pages/team/share_team_select_file/share_team_select_file_controller.dart';
import 'package:get/get.dart';

class ShareTeamSelectFileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShareTeamSelectFileController>(
      () => ShareTeamSelectFileController(),
    );
  }
}

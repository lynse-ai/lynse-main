import 'package:dting/pages/team/search/team_search_file_controller.dart';
import 'package:get/get.dart';

class TeamSearchFileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TeamSearchFileController>(() => TeamSearchFileController());
  }
}

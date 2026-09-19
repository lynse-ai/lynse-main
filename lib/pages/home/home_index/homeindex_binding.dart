import 'package:dting/pages/home/folder_manage/folder_manage_controller.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/pages/personal/my/my_controller.dart';
import 'package:dting/store/dting_store.dart';
import 'package:get/get.dart';

import 'homeindex_controller.dart';

class HomeIndexBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(DtingStore(), permanent: true);
    Get.put(HomeIndexController(), permanent: true);
    // Get.put(SideBarController(), permanent: true);
    Get.put(TeamFileController(), permanent: true);
    Get.put(MyController(), permanent: true);
    // Get.put(TeamsController(), permanent: true);
    // Get.put(VoiceDetailsController(), permanent: true);
  }
}

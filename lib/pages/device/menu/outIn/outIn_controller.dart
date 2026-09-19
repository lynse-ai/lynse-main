import 'package:dting/pages/device/voice_details/voicedetails_controller.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/store/dting_store.dart';
import 'package:get/get.dart';

class OutinController extends GetxController {
  var appController = Get.find<DtingStore>();
  var detailController = Get.find<VoiceDetailsController>();
  var teamFileController = Get.find<TeamFileController>();
  var homeController = Get.find<HomeIndexController>();

  bool get isNotEmpty =>
      appController.selectFileInfo.value.transcribeTaskId != null &&
      detailController.outlnData.value.outlineText != null &&
      detailController.outlnData.value.outlineText != "";

  @override
  Future<void> onInit() async {
    super.onInit();
  }

  @override
  void onClose() {
    Get.delete<OutinController>();
    print("退出OutinController");
    super.onClose();
  }
}

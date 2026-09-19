import 'package:dting/pages/device/audio_sure/audio_sure_controller.dart';
import 'package:dting/pages/device/menu/concel/concel_controller.dart';
import 'package:dting/pages/device/menu/mind/mind_controller.dart';
import 'package:dting/pages/device/menu/outIn/outIn_controller.dart';
import 'package:dting/pages/device/menu/trans/trans_controller.dart';
import 'package:dting/pages/device/tabview/tableview_controller.dart';
import 'package:get/get.dart';

import 'voicedetails_controller.dart';

class VoiceDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(VoiceDetailsController());
    Get.put(TableViewController());
    Get.put(TransController());
    Get.put(OutinController());
    Get.put(ConcelController());
    Get.put(MindController());
    Get.put(AudioSureController());
  }
}

import 'package:dting/pages/device/audio_sure/audio_sure_controller.dart'; 
import 'package:get/get.dart';

class AudioSureBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AudioSureController>(() => AudioSureController());
  }
}

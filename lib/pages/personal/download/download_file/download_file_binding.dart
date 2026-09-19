import 'package:get/get.dart';

import 'download_file_controller.dart'; 

class DownloadFileBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(DownloadFileController());
  }
}

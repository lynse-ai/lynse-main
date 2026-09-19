import 'package:dting/pages/personal/download/download_folder/download_folder_controller.dart';
import 'package:get/get.dart';
 

class DownloaFolderdBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(DownloadFolderController());
  }
}

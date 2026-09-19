import 'package:dting/pages/home/folder_manage/folder_manage_controller.dart';
import 'package:get/get.dart'; 

class SideBarBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(SideBarController());
  }
}

 
import 'package:get/get.dart';

import 'tableview_controller.dart';
  
 

class TablevViewBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(TableViewController()); 
  }
}

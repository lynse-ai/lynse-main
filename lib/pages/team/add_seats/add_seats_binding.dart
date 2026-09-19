import 'package:dting/pages/team/add_seats/add_seats_controller.dart'; 
import 'package:get/get.dart';
 

class AddSeatsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AddSeatsController>(() => AddSeatsController());
  }
}

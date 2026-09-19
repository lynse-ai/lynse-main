import 'package:dting/pages/team/member/member_controller.dart';
import 'package:get/get.dart';
 

class MemberBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MemberController>(() => MemberController());
  }
}

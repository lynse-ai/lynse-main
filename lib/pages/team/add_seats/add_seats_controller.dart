import 'package:dting/model/teams_model/seat_package_model.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/service/point_service.dart';
import 'package:get/get.dart';

class AddSeatsController extends GetxController {
  var teamFileController = Get.find<TeamFileController>();

  var seatPackageList = <SeatPackageModel>[].obs;
  var selectPackage = SeatPackageModel(id: '', teamSeatPackageCode: '').obs;
  @override
  void onInit() {
    super.onInit();
    initPurchasePoint();
  }

  initPurchasePoint() {
    PointService.geSeatPackageList().then((val) {
      seatPackageList.value = val;
    });
  }

  void addSeatTeamPay() {
    //购买席位
  }
}

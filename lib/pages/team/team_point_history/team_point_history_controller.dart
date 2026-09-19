import 'package:dting/model/payment/point_history_log.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/service/point_service.dart';
import 'package:get/get.dart';

class TeamPointHistoryController extends GetxController {
  var versionString = "".obs;
  var pointHistoryList = <PointHisToryLogModel>[].obs;
  var teamFileController = Get.find<TeamFileController>();

  @override
  void onInit() {
    super.onInit();
    getPointLog();
  }

  void getPointLog() {
    PointService.queryPointsLog(
      pointsLogType: 'team',
      teamId: teamFileController.currentTeam.value.id,
    ).then((val) {
      pointHistoryList.value = val;
    });
  }
}

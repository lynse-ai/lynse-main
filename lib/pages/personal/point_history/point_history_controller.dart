import 'package:dting/model/payment/point_history_log.dart';
import 'package:dting/service/point_service.dart';
import 'package:get/get.dart';

class PointHistoryController extends GetxController {
  var versionString = "".obs;
  var pointHistoryList = <PointHisToryLogModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    getPointLog();
  }

  void getPointLog() {
    PointService.queryPointsLog(pointsLogType: 'personal').then((val) {
      pointHistoryList.value = val;
    });
  }
}

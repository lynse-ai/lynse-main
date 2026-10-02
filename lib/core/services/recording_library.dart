/// 录音库服务：维护 sqlite 录音索引的可订阅状态。
///
/// 设备导入新文件（FileImportedEvent）后自动刷新索引。
library;

import 'package:dting/core/data/recording_repository.dart';
import 'package:dting/core/hardware/models.dart';
import 'package:dting/core/services/device_session_controller.dart';
import 'package:get/get.dart';

class RecordingLibrary extends GetxController {
  RecordingLibrary._();

  static RecordingLibrary get instance => Get.find<RecordingLibrary>();

  static RecordingLibrary init() {
    if (Get.isRegistered<RecordingLibrary>()) return Get.find<RecordingLibrary>();
    final c = RecordingLibrary._();
    Get.put(c, permanent: true);
    return c;
  }

  final RecordingRepository repo = RecordingRepository();

  final recordings = <RecordingEntry>[].obs;
  final loading = false.obs;
  final todayCount = 0.obs;

  /// shell 启动时调用一次
  void bootstrap() {
    refreshLibrary();
    // 设备侧导入新文件 → 自动刷新索引（Xyrix 实时流落盘 / 下载完成）
    ever<ImportedRecording?>(DeviceSessionController.instance.lastImported, (_) {
      refreshLibrary();
    });
  }

  Future<void> refreshLibrary() async {
    loading.value = true;
    try {
      final all = await repo.scanAndSync();
      recordings.assignAll(all);
      todayCount.value = await repo.todayCount();
    } finally {
      loading.value = false;
    }
  }
}

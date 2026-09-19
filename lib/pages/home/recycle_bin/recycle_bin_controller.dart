import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:dting/service/bin_service.dart';
import 'package:dting/service/file_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class RecycleBinController extends GetxController
    with GetSingleTickerProviderStateMixin {
  var appController = Get.find<DtingStore>();

  var binVoiceFilesList = <FileInfoModel>[].obs;
  @override
  void onInit() {
    super.onInit();
    initBinVoiceList();
  }

  var selectedIds = <String>[].obs;
  var hasFirstShake = false.obs;

  void onItemSelected(String id) {
    if (!selectedIds.contains(id)) {
      selectedIds.add(id);
    }
  }

  void initBinVoiceList({String category = "BIN"}) {
    FileService.getFileByCategory(category: category).then((res) async {
      binVoiceFilesList.value = res;
    });
  }

  @override
  void onClose() {
    super.onClose();
  }

  //回收站
  Future<void> refreshVoice(FileInfoModel voice) async {
    //复原音频
    await EasyLoading.show();
    try {
      await BinService.recoverFile(fileIds: voice.id!).then((val) async {
        if (val != null && val.code == 200) {
          binVoiceFilesList.remove(voice);
        }
      });
      binVoiceFilesList.refresh();
      Get.find<HomeIndexController>().initVoiceList();
    } catch (e) {
      print("恢复回收站数据:$e");
    } finally {
      await EasyLoading.dismiss();
    }
  }
}

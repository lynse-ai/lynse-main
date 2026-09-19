import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:dting/service/file_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SearchFileController extends GetxController
    with GetTickerProviderStateMixin {
  var appController = Get.find<DtingStore>();
  var homeController = Get.find<HomeIndexController>();

  TextEditingController searchFileController = TextEditingController();
  var allVoiceFilesList = <FileInfoModel>[].obs;
  var searchVoiceFilesList = <FileInfoModel>[].obs;
  FocusNode focusNode = FocusNode();
  var isSearched = false.obs;
  @override
  void onInit() {
    super.onInit();
    // initVoiceList();
    initSearchVoiceList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
    });
  }

  @override
  void onClose() {
    super.onClose();
    focusNode.dispose();
    searchFileController.dispose();
    isSearched.value = false;
  }

  initSearchVoiceList() {
    allVoiceFilesList.value = homeController.voiceList;
    // searchVoiceFilesList.value = homeController.voiceList;
  }

  // Future<void> initVoiceList({String category = "ALL"}) async {
  //   EasyLoading.show();
  //   await FileService.getFileByCategory(category: category).then((res) async {
  //     allVoiceFilesList.value = res;
  //      searchVoiceFilesList.value = allVoiceFilesList;
  //   });
  //   EasyLoading.dismiss();
  // }

  Future<void> readVoice(FileInfoModel voice) async {
    if (appController.selectFileInfo.value.id != null &&
        appController.selectFileInfo.value.id != voice.id) {
      appController.isPlay.value = false;
    }
    appController.selectFileInfo.value = voice;
    if (voice.isRead == 0) {
      await FileService.markRead(fileId: voice.id!).then((val) {
        if (val) {
          var existVoice = allVoiceFilesList.firstWhereOrNull(
            (voiceItem) => voiceItem.id == voice.id,
          );

          if (existVoice != null) {
            existVoice.isRead = 1;
            allVoiceFilesList.refresh();
          }
        }
      });
    }
    NavigationUtils.toVoiceDetails();
  }

  void searchVoiceList() {
    isSearched.value = true;
    var search = searchFileController.text.trim();
    searchVoiceFilesList.value =
        allVoiceFilesList
            .where((voice) => voice.originalFilename!.contains(search))
            .toList();
  }
}

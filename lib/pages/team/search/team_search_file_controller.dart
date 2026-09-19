import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/store/dting_store.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TeamSearchFileController extends GetxController
    with GetTickerProviderStateMixin {
  var appController = Get.find<DtingStore>();
  var teamFileController = Get.find<TeamFileController>();

  TextEditingController searchFileController = TextEditingController();
  var allVoiceFilesList = <FileInfoModel>[].obs;
  var searchVoiceFilesList = <FileInfoModel>[].obs;

  FocusNode focusNode = FocusNode();
  @override
  void onInit() {
    super.onInit();

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
  }

  initSearchVoiceList() {
    allVoiceFilesList.value = teamFileController.voiceList;
    // searchVoiceFilesList.value = homeController.voiceList;
  }

  void searchVoiceList() {
    var search = searchFileController.text.trim();
    searchVoiceFilesList.value =
        allVoiceFilesList
            .where((voice) => voice.originalFilename!.contains(search))
            .toList();
  }
}

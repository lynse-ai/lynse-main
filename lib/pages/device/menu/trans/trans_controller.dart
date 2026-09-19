import 'package:dting/model/file_model/file_processing_model/edit_trans_model.dart';
import 'package:dting/model/file_model/file_processing_model/trans_model.dart';
import 'package:dting/pages/device/voice_details/voicedetails_controller.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/service/file_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class TransController extends GetxController {
  var appController = Get.find<DtingStore>();
  var detailController = Get.find<VoiceDetailsController>();
  var teamFileController = Get.find<TeamFileController>();
  var homeController = Get.find<HomeIndexController>();

  bool get isNotEmpty =>
      appController.selectFileInfo.value.transcribeTaskId != null &&
      detailController.transcrSpeakList.isNotEmpty;

  // var selectSpeaker = TransModel().obs;
  // TextEditingController editSpeakerName = TextEditingController();
  var editTransList = <EditTransModel>[].obs; //需要修改的数据
  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onClose() {
    Get.delete<TransController>();
    print("退出trans");
    super.onClose();
  }

  //修改所有改名的speaker Name
  void editAllSpeackName(TransModel speakDetail, String editText) {
    var existSpeackNameList =
        detailController.transcrSpeakList
            .where((trans) => trans.speakerId == speakDetail.speakerId)
            .toList();
    for (var editTrans in existSpeackNameList) {
      var existEdit = editTransList.firstWhereOrNull(
        (edit) => edit.recordId == editTrans.id,
      );
      if (existEdit != null) {
        existEdit.speakerName = editText;
      } else {
        editTransList.add(
          EditTransModel(
            recordId: editTrans.id,
            speakerId: editTrans.speakerId,
            speakerName: editText,
            text: editTrans.text,
          ),
        );
      }
      editTrans.speakerName = editText;
    }
    //强制刷新界面
    update(["updateTransList"]);
  }

  Future<void> editTransSpeakList() async {
    if (editTransList.isNotEmpty) {
      await EasyLoading.show();
      try {
        final res = await FileService.editTransList(editTransList);
        if (res != null) {
          if (res.code == 200) {
            editTransList.value = [];
            await detailController.getTransData();
            Get.back();
          } else if (res.code == 4001) {
            // editTransList.value = [];
            await EasyLoading.dismiss(); // 先关 loading
            DialogHelper.showToastDialog(res.msg);
          } else {
            await EasyLoading.dismiss(); // 先关 loading
            DialogHelper.showToastDialog(res.msg);
          }
        }
      } catch (error) {
        print(error);
        await EasyLoading.dismiss();
      } finally {
        // 避免重复关闭，但如果上面已经关闭，这里不会有影响
        if (EasyLoading.isShow) {
          await EasyLoading.dismiss();
        }
      }
    } else {
      DialogHelper.showToastDialog("editTip");
    }
  }

  //只修改一个speak name
  void editItemSpeackName(
    TransModel speakDetail,
    String editText,
    Rx<String?> speakerNameString,
  ) {
    var existEdit = editTransList.firstWhereOrNull(
      (edit) => edit.recordId == speakDetail.id,
    );
    if (existEdit != null) {
      existEdit.speakerName = editText;
    } else {
      editTransList.add(
        EditTransModel(
          recordId: speakDetail.id,
          speakerId: speakDetail.speakerId,
          speakerName: editText,
          text: speakDetail.text,
        ),
      );
    }
    speakerNameString.value = editText;
  }

  void editTransText(TransModel speakDetail, String value) {
    speakDetail.text = value;
    var existEdit = editTransList.firstWhereOrNull(
      (edit) => edit.recordId == speakDetail.id,
    );
    if (existEdit != null) {
      existEdit.text = value;
    } else {
      editTransList.add(
        EditTransModel(
          recordId: speakDetail.id,
          speakerId: speakDetail.speakerId,
          speakerName: speakDetail.speakerName,
          text: value,
        ),
      );
    }
  }
}

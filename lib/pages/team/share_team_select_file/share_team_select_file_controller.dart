import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/model/teams_model/teams_model.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/service/file_service.dart';
import 'package:dting/service/team_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:get/get.dart';

class ShareTeamSelectFileController extends GetxController {
  var appController = Get.find<DtingStore>();
  var teamFileController = Get.find<TeamFileController>();
  var homeController = Get.find<HomeIndexController>();

  var selectVoiceFilesList = <FileInfoModel>[].obs;
  var voiceFilesList = <FileInfoModel>[].obs; //所有文件

  // var teamsList = <TeamsModel>[].obs; //所有的团队

  // var currentVoiceFile = ResponseShareTeamModel.genDefault().obs;
  @override
  void onInit() {
    super.onInit();
    //全局使用currentVoiceFile.value.fileId、以及teamId来进行API功能的使用

    initVoiceList();
  }

  @override
  void onClose() {
    super.onClose();
  }

  // //获取团队数据
  // Future<void> getAllTeamList() async {
  //   await TeamService.getTeamListByUserId().then((val) {
  //     teamsList.value = val;
  //   });
  // }

  //获取个人文件数据
  initVoiceList() async {
    if (homeController.voiceList.isEmpty) {
      voiceFilesList.value = homeController.voiceList;
    } else {
      try {
        await FileService.getFileByCategory(category: "ALL")
            .then((res) async {
              voiceFilesList.value = res;
            })
            .whenComplete(() {});
      } catch (error) {
        print(error);
      }
    }
  }

  //移动音频文件并且数据刷新
  void copyOrMoveFileList({
    required bool copyOrMove,
    required bool isPersonal,
    required List<TeamsModel> selectTeamList,
  }) {
    List<String> tempTeamList = [];
    for (var team in selectTeamList) {
      tempTeamList.add(team.id);
    }
    List<String> tempVoiceList = [];
    for (var voice in selectVoiceFilesList) {
      tempVoiceList.add(voice.id!);
    }

    if (tempTeamList.isEmpty) {
      DialogHelper.showToastDialog("selectTeam");
      return;
    }
    var fileSourceTypeString = "PERSONAL";

    if (!isPersonal) {
      fileSourceTypeString = 'TEAM';
    }
    if (copyOrMove) {
      //复制
      TeamService.shareVoiceFileList(
        fileIds: tempVoiceList,
        actionType: "COPY",
        teamIds: tempTeamList,
        sourceType: fileSourceTypeString,
      ).then((val) {
        if (val != null) {
          if (val.code == 200) {
            selectVoiceFilesList.value = [];
            Get.back();
            //团队数据刷新
            teamFileController.initVoiceListByTeamId();
            DialogHelper.showToastDialog("copySuccessGotoTeam");
          } else {
            var mes = val.msg;
            DialogHelper.showToastDialog(mes);
          }
        }
      });
    } else {
      //移动
      TeamService.shareVoiceFileList(
        fileIds: tempVoiceList,
        actionType: "MOVE",
        teamIds: tempTeamList,
        sourceType: fileSourceTypeString,
      ).then((val) {
        if (val != null) {
          if (val.code == 200 && val.data != null) {
            selectVoiceFilesList.value = [];
            Get.back();
            //团队数据刷新
            teamFileController.initVoiceListByTeamId();
            DialogHelper.showToastDialog("moveSuccessGotoTeam");
          } else {
            if (val.code == 1001) {
              DialogHelper.showToastDialog("moveIngNotSupport");
            } else {
              var mes = val.msg;
              DialogHelper.showToastDialog(mes);
            }
          }
        }
      });
    }
  }
}

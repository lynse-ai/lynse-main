import 'dart:convert';
import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/model/file_model/folder_management_model/change_folder_index_model.dart';
import 'package:dting/model/file_model/folder_management_model/folder_model.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:dting/pages/home/folder_manage/widget/move_file_to_otherfolder_widget.dart';
import 'package:dting/service/file_service.dart';
import 'package:dting/service/folder_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

class SideBarController extends GetxController
    with GetSingleTickerProviderStateMixin {
  var appController = Get.find<DtingStore>();
  var homeController = Get.find<HomeIndexController>();
  var moveSelectFolder = FolderInfo(id: '').obs;

  // 是否编辑中状态
  RxBool isEdit = false.obs;

  TextEditingController createFolderController = TextEditingController();

  var folderList = <FolderInfo>[].obs; //API返回的所有folder name
  var folderListAndAll = <FolderInfo>[].obs; //All 、Unclassified、folder name
  Map<String?, SlidableController> slibableControllers = {};
  var changeFolderList = <ChangeFodlerIndexModel>[].obs; //修改文件的下表数据

  @override
  void onInit() {
    super.onInit();
    getAllFolder();
  }

  @override
  void dispose() {
    super.dispose();
    for (var element in slibableControllers.entries) {
      element.value.close();
    }
  }

  //重置数据
  void resetData() {
    moveSelectFolder.value = FolderInfo(id: '');
    createFolderController.text = "";
    folderList.value = [];
  }

  // 改进：总是从服务器获取最新文件夹列表，而不是依赖homeController的缓存
  Future<void> getAllFolder() async {
    try {
      // 直接从服务器获取最新的文件夹列表
      final res = await FolderService.folderList();
      folderList.value = res;
      // 同时更新homeController的folderList
      homeController.folderList.value = res;
    } catch (e) {
      print('获取文件夹列表失败: $e');
    }
  }

  //获取所有语音数据
  Future<void> getBinVoiceList({String category = "BIN"}) async {
    await FileService.getFileByCategory(category: category).then((res) async {
      homeController.showVoiceList.value = res;
      Get.back();
    });
  }

  void initCreatefolderAndRemoveFile() {
    moveSelectFolder.value = FolderInfo(id: "");
    createFolderController.text = "";
  }

  Future<void> editFolderName({
    required String editName,
    required String folderId,
  }) async {
    FolderService.editFolder(folderName: editName, folderId: folderId).then((
      val,
    ) async {
      if (val != null) {
        if (val.code == 200 && val.data != null) {
          // 改进：确保获取最新列表
          await getAllFolder();
          homeController.initVoiceList();
          DialogHelper.showToastDialog("editSuccessful");
          Get.back();
        } else {
          var message = val.msg;
          print(message);
          DialogHelper.showToastDialog(message);
        }
      }
    });
  }

  int getByteLength(String text) {
    return utf8.encode(text).length;
  }

  void createFolder({bool backMoveToFolder = false}) async {
    var folderName = createFolderController.text.trim();
    if (folderName.isEmpty) {
      // 非空检查
      DialogHelper.showToastDialog("cannotEmpty");
    } else if (folderList
        .where((folder) => folder.folderName == folderName)
        .isNotEmpty) {
      // 同名检查
      DialogHelper.showToastDialog("existsFile");
    } else {
      await EasyLoading.show();
      await FolderService.createFolder(folderName: folderName).then((
        res,
      ) async {
        if (res != null) {
          if (res.code == 200 && res.data != null) {
            homeController.isMoreSelect.value = false;
            homeController.selectVoiceFileList.value = [];
            createFolderController.text = "";
            // 改进：确保从服务器获取最新列表
            await getAllFolder();
            Get.back();
            if (backMoveToFolder) {
              Future.delayed(Duration.zero, () {
                Get.bottomSheet(
                  MoveFileToOtherfolderWidget(
                    selectRemoveVoiceList: [appController.selectFileInfo.value],
                  ),
                  isScrollControlled: true,
                );
              });
            }
          } else {
            DialogHelper.showToastDialog(res.msg);
          }
        }
      });

      await EasyLoading.dismiss();
    }
  }

  // 改进：删除文件夹后确保获取最新列表并保持顺序
  void deleteFolder(String id) async {
    await EasyLoading.show();
    try {
      final res = await FolderService.deleteFile(fileIds: [], folderIds: [id]);
      if (res != null && res.code == 200 && res.data != null) {
        // 直接从服务器获取最新的文件夹列表，而不是依赖homeController的缓存
        await getAllFolder();
        homeController.initVoiceList();
      } else {
        var message = res?.msg ?? "删除失败";
        print(message);
        DialogHelper.showToastDialog(message);
      }
    } catch (e) {
      print('删除文件夹异常: $e');
      DialogHelper.showToastDialog("删除失败");
    } finally {
      await EasyLoading.dismiss();
    }
  }

  Future moveFileByOtherFolder(
    List<FileInfoModel> selectRemoveVoiceList,
  ) async {
    //移动文件至 moveSelectFolder 文件夹
    var newFolderId = moveSelectFolder.value.id;
    var cuttentFile = appController.selectFileInfo.value;
    if (newFolderId.isNotEmpty && newFolderId != "-1" && newFolderId != "-2") {
      if (newFolderId == cuttentFile.folderId) {
        DialogHelper.showToastDialog("existsFolder");
      } else {
        String fileIdString = selectRemoveVoiceList.map((m) => m.id).join(',');
        await FileService.moveFile(
          newFolderId: newFolderId,
          fileIds: fileIdString,
        ).then((res) {
          if (res != null) {
            if (res.code == 200) {
              for (var remove in selectRemoveVoiceList) {
                var existVoice = homeController.voiceList.firstWhereOrNull(
                  (voice) => voice.id == remove.id,
                );
                if (existVoice != null) {
                  existVoice.folderId = newFolderId;
                  existVoice.folderName =
                      folderList
                          .firstWhere((folder) => folder.id == newFolderId)
                          .folderName;
                  homeController.voiceList.refresh();
                  appController.selectFileInfo.value = existVoice;
                  homeController.setShowVoiceList(
                    folderId: appController.selectFolderFolder.value.id,
                  );
                }
              }
              homeController.selectVoiceFileList.value = [];
              homeController.isMoreSelect.value = false;
              DialogHelper.showToastDialog("successful");
            } else {
              var message = res.msg;
              print(message);
            }
          }
        });
        Get.back();
      }
    } else {
      DialogHelper.showToastDialog("selectFolder");
    }
  }

  //调整folder卡片的位置
  void reorder(int oldIndex, int newIndex) {
    var handerFolder = folderList[oldIndex];

    if (newIndex > oldIndex) newIndex -= 1; // 修正索引
    if (oldIndex < 0 || oldIndex >= folderList.length) return;
    if (newIndex < 0 || newIndex > folderList.length) return;
    changeFolderList.add(
      ChangeFodlerIndexModel(sort: newIndex, folderId: handerFolder.id),
    );
    final moved = folderList.removeAt(oldIndex);
    folderList.insert(newIndex, moved);
  }

  //批量更新folder的位置
  void batchUpdateSort() async {
    if (changeFolderList.isNotEmpty) {
      bool isSuccess = await FolderService.editFolderIndex(changeFolderList);
      if (isSuccess) {
        homeController.folderList.value = [...folderList];
        changeFolderList.value = [];
        DialogHelper.showToastDialog("sortSuccessful");
      }
      isEdit.value = !isEdit.value;
    }
  }

  //处理编辑按钮的点击事件
  void handleEditTap() {
    if (isEdit.value) {
      batchUpdateSort();
    } else {
      isEdit.value = true;
    }
  }
}

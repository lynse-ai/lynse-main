import 'dart:async';
import 'dart:io';
import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/model/file_model/file_management_model/upload_file_model.dart';
import 'package:dting/model/file_model/folder_management_model/folder_model.dart';
import 'package:dting/model/teams_model/inviter_team_model.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';
import 'package:dting/service/file_service.dart';
import 'package:dting/service/folder_service.dart';
import 'package:dting/service/personal_service.dart';
import 'package:dting/service/team_service.dart';
import 'package:dting/service/network_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/datetime_helper.dart';
import 'package:dting/utils/local_sqldb.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/utils/oss_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class HomeIndexController extends GetxController
    with GetTickerProviderStateMixin {
  var appController = Get.find<DtingStore>();
  NetworkService get networkService => NetworkService.to;

  var selectFile = FileInfoModel().obs; //当前选择操作的文件
  var voiceList = <FileInfoModel>[].obs;
  var showVoiceList = <FileInfoModel>[].obs;

  // 待上传文件列表
  var uploadQueue = <Map<String, dynamic>>[].obs;
  var isUploadingQueue = false.obs;

  // 正在上传的文件路径集合，用于去重
  var uploadingFiles = <String>{}.obs;

  //会议类型，两种模式，会议录音和通话录音

  //是否开始录音
  var bottomMenuIndex = 0.obs; //总是在个人文件
  var isMoreSelect = false.obs; //是否显示多选

  var selectVoiceFileList = <FileInfoModel>[].obs; //多选其他数据
  late TabController tabController;
  var folderList = <FolderInfo>[].obs; //API返回的所有folder
  var isReceive = 0.obs; //是否领取积分

  //用于显示我的当前邀请
  var inviteMeListByOther = <InviterTeamModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    print('HomeIndexController  的 init 函数执行了');

    isReceive.value = appController.userInfo.value.initialRewardClaimed ?? 0;
    tabController = TabController(length: 3, vsync: this);
    tabController.addListener(_onTabChanged); // 添加监听器

    // 初始化网络监听
    _initNetworkMonitoring();

    // 将上传中状态的文件更新为上传失败
    _resetUploadingStatus();

    getAllFolder();
    initVoiceList();
    loadUploadQueue();
  }

  Future<bool> checkTextLegality({required String text}) async {
    return await FileService.checkTextValidity(text, CheckAction.FILE_UPLOAD);
  }

  void _initNetworkMonitoring() {
    // 监听网络连接恢复
    networkService.addOnConnectedCallback(() {
      print('网络已连接，开始处理待上传文件');
      // 添加延迟，避免频繁触发
      Future.delayed(Duration(milliseconds: 1000), () {
        if (networkService.isConnected.value && !isUploadingQueue.value) {
          _processUploadQueue();
        }
      });
    });

    // 监听网络断开
    networkService.addOnDisconnectedCallback(() {
      print('网络已断开');
    });
  }

  // 重置上传中状态的文件为上传失败
  Future<void> _resetUploadingStatus() async {
    try {
      // 使用SqlDBHelper的静态方法重置上传中状态的文件
      final count = await SqlDBHelper.resetUploadingStatus();
      if (count > 0) {
        print('成功重置 $count 个上传中断的文件为上传失败状态');

        // 检查数据库中的文件是否存在，如果不存在则删除记录
        final allUploads = await SqlDBHelper.getDisplayUploadQueue();
        int removedCount = 0;

        for (final uploadData in allUploads) {
          final filePath = uploadData['path'] as String;
          final id = uploadData['id'] as int;

          if (!File(filePath).existsSync()) {
            print('文件不存在，从待上传队列中删除: $filePath');
            await SqlDBHelper.removeUploadedFile(id);
            removedCount++;
          }
        }

        if (removedCount > 0) {
          print('已删除 $removedCount 个不存在的文件记录');
          // 刷新待上传队列列表
          await loadUploadQueue();
        }

        // 重置状态后，如果网络连接正常，延迟处理上传队列
        if (networkService.isConnected.value) {
          print('网络已连接，开始处理重置后的待上传文件');
          Future.delayed(Duration(milliseconds: 500), () {
            if (networkService.isConnected.value && !isUploadingQueue.value) {
              _processUploadQueue();
            }
          });
        }
      } else {
        final allUploads = await SqlDBHelper.getDisplayUploadQueue();
        int removedCount = 0;

        for (final uploadData in allUploads) {
          final filePath = uploadData['path'] as String;
          final id = uploadData['id'] as int;

          if (!File(filePath).existsSync()) {
            print('文件不存在，从待上传队列中删除: $filePath');
            await SqlDBHelper.removeUploadedFile(id);
            removedCount++;
          }
        }

        if (removedCount > 0) {
          print('已删除 $removedCount 个不存在的文件记录');
        }

        // 重置状态后，如果网络连接正常，延迟处理上传队列
        if (networkService.isConnected.value) {
          print('网络已连接，开始处理重置后的待上传文件');
          Future.delayed(Duration(milliseconds: 500), () {
            if (networkService.isConnected.value && !isUploadingQueue.value) {
              _processUploadQueue();
            }
          });
        }
      }
    } catch (e) {
      print('重置上传中状态失败: $e');
    }
  }

  //重置数据
  void resetData() {
    voiceList.clear();
    selectFile.value = FileInfoModel();
    selectVoiceFileList.clear();
    showVoiceList.clear();
    isMoreSelect.value = false;
    isReceive.value = 0;
    bottomMenuIndex.value = 0;
    folderList.clear();
    tabController.index = 0;
  }

  //底部标签切换
  void _onTabChanged() {
    if (tabController.index == 0) {
      appController.handleForeground();
      try {
        getAllFolder();
        initVoiceList();
      } catch (e) {
        print('');
      }
    } else if (tabController.index == 1) {
      // 检测团队标签页切换
      try {
        final teamController = Get.find<TeamFileController>();
        teamController.refreshTeamData(); // 刷新团队信息、刷新文件列表
      } catch (e) {
        print('Failed to refresh team data: \$e');
      }
    }
  }

  getAllFolder() {
    FolderService.folderList().then((res) {
      folderList.value = res;
    });
  }

  @override
  void onClose() {
    super.onClose();
    appController.handleBackground();
    print("真的退出了home close");
  }

  void changePage(int index) {
    bottomMenuIndex.value = index;
    // pageController.jumpToPage(index); // 可改为 animateToPage
    tabController.index = index;
  }

  void updateDeviceParameters() {
    update(["updateConnectDevice"]);
  }

  // 导入语音数据 应该还有设备码 还有本地地址
  Future<void> importVoiceCard() async {
    appController.isShowFileDialog.value = true;
    await getDeviceFileList();
    // await showConnectDeviceFileDialog();
  }

  //选择硬件中的文件进行快传
  Future<void> showConnectDeviceFileDialog() async {
    if (appController.connectDeviceFileList.isEmpty) {
      DialogHelper.showToastDialog("noRecording");
      return;
    }

    // 通过全局标识，控制重复点击出现多个弹窗
    final dtingStore = Get.find<DtingStore>();
    final isShow = dtingStore.isShowDeviceFileList.value;
    if (!isShow) {
      dtingStore.isShowDeviceFileList.value = true;
      try {
        await DialogHelper.showConnectDeviceFiles(
          fileList: appController.connectDeviceFileList,
          okOntap: (sn, downType) async {
            downLoadFile(sn, downType: downType);
          },
        ).then((value) {
          dtingStore.isShowDeviceFileList.value = false;
        });
      } finally {
        dtingStore.isShowDeviceFileList.value = false;
      }
    }
  }

  //快传
  void downLoadFile(int sn, {int downType = 0}) async {
    await EasyLoading.show();

    try {
      appController.deviceFileUploading.value = true;
      NvEasyPlugin().initOpus(true);

      if (downType == 1) {
        // WiFi快传
        print("开始WiFi快传下载文件: $sn");
        await NvEasyPlugin().downLoadFileWifi(sn);
        // WiFi快传需要用户手动连接热点，所以不立即关闭loading
        // 等待WiFi状态变化或文件下载完成
      } else {
        // 蓝牙下载
        print("开始蓝牙下载文件: $sn");
        await NvEasyPlugin().downLoadFile(sn);
        await EasyLoading.dismiss();
      }
    } catch (e) {
      print("文件下载失败: $e");
      await EasyLoading.dismiss();
      DialogHelper.showToastDialog("wifiFail");
    }
  }

  //获取硬件中的所有文件
  getDeviceFileList() async {
    if (appController.connectingDevice.value.macAddress != null) {
      await NvEasyPlugin().getFileList();
    } else {
      DialogHelper.showToastDialog("No device connected");
    }
  }

  //导入语音数据 应该还有设备码 还有本地地址
  Future<void> importVoice() async {
    FilePickerResult? localVoiceList = await FilePicker.platform.pickFiles();

    if (localVoiceList != null && localVoiceList.files.isNotEmpty) {
      var file = localVoiceList.files.first;
      if (file.extension != null) {
        if (file.extension!.toLowerCase() != "wav" &&
            file.extension!.toLowerCase() != "mp3" &&
            file.extension!.toLowerCase() != "m4a" &&
            file.extension!.toLowerCase() != "aac" &&
            file.extension!.toLowerCase() != "ogg" &&
            file.extension!.toLowerCase() != "amr" &&
            file.extension!.toLowerCase() != "flac") {
          DialogHelper.showToastDialog("selectAudio");
        } else {
          String multiFilePath = "";
          String nameString = "";
          if (localVoiceList.xFiles.first.path.isNotEmpty) {
            try {
              await EasyLoading.show();
              multiFilePath = localVoiceList.xFiles.first.path;
              nameString = localVoiceList.xFiles.first.name;

              // if (PermissionsHelper.isIOS()) {
              //   await transIosPath(multiFilePath, nameString).then((iosPath) {
              //     final file = File(iosPath);
              //     if (file.existsSync()) {
              //       multiFilePath = iosPath;
              //     }
              //   });
              // }
              final fileSize = File(multiFilePath).lengthSync();
              await updateFileByOss(
                multiFilePath: multiFilePath,
                fileSize: fileSize,
                saveFileName: nameString,
                recordTime: DateTimeHelper.dateTimeCoverTOString(
                  DateTime.now(),
                ),
              );
              await EasyLoading.dismiss();
            } catch (e) {
              DialogHelper.showToastDialog("importFail");
              await EasyLoading.dismiss();
            }
          }
        }
      }
    }
  }

  //上传音频文件
  updateFileByOss({
    required String multiFilePath,
    required int fileSize,
    required String recordTime,
    int? fileDuration,
    String? saveFileName,
    int? scene,
  }) async {
    try {
      if (multiFilePath.isNotEmpty) {
        final audioPlayer = AudioPlayer();
        await audioPlayer.setFilePath(multiFilePath);
        print("----updateFileByOss 音频文件大小  $fileSize");
        print("----updateFileByOss 音频文件时长fileDuration  $fileDuration");
        print("----updateFileByOss 音频录音开始时间 $recordTime");

        // 录音卡上传则传递fileDuration参数，本地文件则直接获取音频文件的duration作为时长
        int time = 0;

        if (fileDuration != null && fileDuration > 0) {
          time = fileDuration;
        } else if (audioPlayer.duration != null) {
          time = DateTimeHelper.convertDurationTransSecond(
            audioPlayer.duration!,
          );
        }
        if (time == 0) {
          DialogHelper.showToastDialog("emptyDuration");
          return;
        }
        print("----updateFileByOss 音频文件时长  $time");

        //查询当前文件的文件夹
        String? foldIdString;
        if (appController.selectFolderFolder.value.id != "-1" &&
            appController.selectFolderFolder.value.id != "-2" &&
            appController.selectFolderFolder.value.id != "-4" &&
            appController.selectFolderFolder.value.id != "-5" &&
            appController.selectFolderFolder.value.id != "-6") {
          foldIdString = appController.selectFolderFolder.value.id;
        }
        //当前文件的硬件模式
        String modeTypeString = "IMPORT";
        if (scene != null) {
          if (scene == 0) {
            modeTypeString = "MEETING";
          } else {
            modeTypeString = "CALL";
          }
        }
        //为每个文件生成唯一的文件名
        String saveFileNameString;
        if (saveFileName != null) {
          saveFileNameString = saveFileName;
        } else {
          // 使用文件的实际录音时间作为文件名，确保每个文件都有唯一名称
          final fileTitle =
              recordTime != ''
                  ? recordTime
                  : DateTimeHelper.dateTimeCoverTOString(DateTime.now());
          saveFileNameString = "${fileTitle}.mp3";
        }
        //以上是设置saveFileName
        UploadFileModel uploadForOss = UploadFileModel(
          customerId: appController.userInfo.value.id,
          folderId: foldIdString,
          path: multiFilePath,
          macAddress: appController.connectingDevice.value.macAddress ?? "",
          location: appController.location.value,
          saveFilename: saveFileNameString,
          bizDuration: time,
          mode: modeTypeString,
          fileSize: fileSize,
          recordStartTime: recordTime,
          scene: scene ?? -1,
        );

        // 检查网络状态
        // if (!networkService.isConnected.value) {
        // 网络断开，存储到本地数据库
        print('网络断开，将文件存储到待上传队列');
        await SqlDBHelper.insertUploadQueue(uploadForOss);
        await loadUploadQueue();

        await _processUploadQueue();
        // DialogHelper.showToastDialog("网络断开，文件已加入待上传队列");
        return;
        // }

        // 网络连接正常，直接上传
        // await _uploadFile(uploadForOss);
      }
    } catch (e) {
      print("文件上传error：$e");
    }
  }

  // 加载待上传队列
  Future<void> loadUploadQueue() async {
    try {
      // 只加载待上传、上传中、上传失败的文件，不包括已成功上传的
      final queue = await SqlDBHelper.getDisplayUploadQueue();
      uploadQueue.value = queue;
      print('加载待上传队列: ${queue.length} 个文件');
    } catch (e) {
      print('加载待上传队列失败: $e');
    }
  }

  // 处理待上传队列
  Future<void> _processUploadQueue() async {
    if (isUploadingQueue.value) {
      print('上传队列正在处理中，跳过重复调用');
      return;
    }

    isUploadingQueue.value = true;
    print('开始处理上传队列');

    try {
      final pendingUploads = await SqlDBHelper.getPendingUploads();
      print('开始处理待上传文件: ${pendingUploads.length} 个');

      // 检查文件是否存在，如果不存在则从数据库中删除
      for (int i = pendingUploads.length - 1; i >= 0; i--) {
        final uploadData = pendingUploads[i];
        final filePath = uploadData['path'] as String;
        final id = uploadData['id'] as int;

        if (!File(filePath).existsSync()) {
          print('文件不存在，从待上传队列中删除: $filePath');
          await SqlDBHelper.removeUploadedFile(id);
          pendingUploads.removeAt(i);
        }
      }

      print('检查后待上传文件: ${pendingUploads.length} 个');

      // 使用循环而不是递归，避免重复调用
      for (final uploadData in pendingUploads) {
        if (!networkService.isConnected.value) {
          print('网络断开，停止上传队列处理');
          break;
        }

        final uploadFile = _mapToUploadFileModel(uploadData);
        final id = uploadData['id'] as int;
        final filePath = uploadFile.path!;

        try {
          // 再次检查文件是否存在
          if (!File(filePath).existsSync()) {
            print('上传前检查：文件不存在，从待上传队列中删除: $filePath');
            await SqlDBHelper.removeUploadedFile(id);
            continue;
          }

          // 检查文件是否正在上传中，避免重复上传
          if (uploadingFiles.contains(filePath)) {
            print('文件正在上传中，跳过重复上传: $filePath');
            continue;
          }

          // 添加到正在上传的文件集合
          uploadingFiles.add(filePath);

          // 更新状态为上传中
          await SqlDBHelper.updateUploadStatus(id, 1);
          await loadUploadQueue();

          // 执行上传
          final fileId = await OssUtilsService().upload(updateFile: uploadFile);

          if (fileId != null) {
            // 上传成功
            await FileService.uploadOssSuccnotify(fileId: fileId);
            await SqlDBHelper.updateUploadStatus(id, 2);

            // 立即删除成功的记录，避免重复处理
            await SqlDBHelper.removeUploadedFile(id);
            await loadUploadQueue();

            print('文件上传成功: ${uploadFile.saveFilename}');
          } else {
            // 上传失败
            await SqlDBHelper.updateUploadStatus(
              id,
              3,
              errorMessage: '上传返回空文件ID',
            );
            print('文件上传失败: ${uploadFile.saveFilename}');
          }
        } catch (e) {
          // 上传异常
          await SqlDBHelper.updateUploadStatus(
            id,
            3,
            errorMessage: e.toString(),
          );
          print('文件上传异常: ${uploadFile.saveFilename}, 错误: $e');
        } finally {
          // 无论成功还是失败，都要从正在上传的文件集合中移除
          uploadingFiles.remove(filePath);
        }

        await loadUploadQueue();

        // 短暂延迟避免过于频繁的请求
        await Future.delayed(Duration(milliseconds: 500));
      }

      // 刷新文件列表
      if (networkService.isConnected.value) {
        await initVoiceList();
      }
    } catch (e) {
      print('处理上传队列异常: $e');
    } finally {
      isUploadingQueue.value = false;
      print('上传队列处理完成');
    }
  }

  UploadFileModel _mapToUploadFileModel(Map<String, dynamic> data) {
    return UploadFileModel(
      customerId: data['customerId'],
      teamId: data['teamId'],
      folderId: data['folderId'],
      path: data['path'],
      macAddress: data['macAddress'],
      location: data['location'],
      saveFilename: data['saveFilename'],
      objectId: data['objectId'],
      bizDuration: data['bizDuration'],
      mode: data['mode'],
      fileSize: data['fileSize'],
      recordStartTime: data['recordStartTime'],
      scene: data['scene'],
    );
  }

  // 手动重试上传
  Future<void> retryUpload(int id) async {
    if (!networkService.isConnected.value) {
      DialogHelper.showToastDialog('网络未连接，无法重试上传');
      return;
    }

    final queue = await SqlDBHelper.getDisplayUploadQueue();
    final uploadData = queue.firstWhere((item) => item['id'] == id);

    if (uploadData.isNotEmpty) {
      final uploadFile = _mapToUploadFileModel(uploadData);
      final filePath = uploadFile.path!;

      // 检查文件是否正在上传中，避免重复上传
      if (uploadingFiles.contains(filePath)) {
        DialogHelper.showToastDialog('文件正在上传中，请稍后重试');
        return;
      }

      // 添加到正在上传的文件集合
      uploadingFiles.add(filePath);

      try {
        await SqlDBHelper.updateUploadStatus(id, 1);
        await loadUploadQueue();

        final fileId = await OssUtilsService().upload(updateFile: uploadFile);

        if (fileId != null) {
          await FileService.uploadOssSuccnotify(fileId: fileId);
          await SqlDBHelper.updateUploadStatus(id, 2);

          // 立即删除成功的记录，避免重复处理
          await SqlDBHelper.removeUploadedFile(id);
          await loadUploadQueue();

          print('文件上传成功');
          if (networkService.isConnected.value) {
            await initVoiceList();
          }
        } else {
          await SqlDBHelper.updateUploadStatus(
            id,
            3,
            errorMessage: '上传返回空文件ID',
          );
          print('文件上传失败');
        }
      } catch (e) {
        await SqlDBHelper.updateUploadStatus(id, 3, errorMessage: e.toString());
        print('文件上传失败: $e');
      } finally {
        // 无论成功还是失败，都要从正在上传的文件集合中移除
        uploadingFiles.remove(filePath);
      }

      await loadUploadQueue();
    }
  }

  // 删除待上传文件
  Future<void> removeFromUploadQueue(int id) async {
    await SqlDBHelper.removeUploadedFile(id);
    await loadUploadQueue();
  }

  // 获取所有的音频文件
  initVoiceList() async {
    try {
      var folder = appController.selectFolderFolder.value;
      selectVoiceFileList.value = []; //清空选中文件
      isMoreSelect.value = false;
      await FileService.getFileByCategory(category: "ALL")
          .then((res) async {
            voiceList.value = res;
            setShowVoiceList(folderId: folder.id);
          })
          .whenComplete(() {});
    } catch (error) {
      print(error);
    }
  }

  //根据文件夹分类音频文件
  void setShowVoiceList({required String folderId}) {
    switch (folderId) {
      case "-1":
        showVoiceList.value = voiceList;
        break;
      case "-2":
        showVoiceList.value =
            voiceList.where((voice) => voice.transcribeTaskId == null).toList();
        break;
      case "-3":
        showVoiceList.value =
            voiceList.where((voice) => voice.isRead == 0).toList();
        break;
      default:
        showVoiceList.value =
            voiceList.where((voice) => voice.folderId == folderId).toList();
        break;
    }
  }

  Future<String> transIosPath(String path, String fileName) async {
    // 原文件路径
    File sourceFile = File(path);
    // 目标文件夹路径
    var targetDir = await getApplicationCacheDirectory();
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true); // 创建目标文件夹
    }
    // 构建目标文件路径
    String newPath = '${targetDir.path}/$fileName';

    // 执行复制
    await sourceFile.copy(newPath);
    return newPath;
  }

  //重命名音频
  void reNameForVoice({String editVoiceName = ""}) {
    var editFile = appController.selectFileInfo.value;

    if (editFile.id != null) {
      if (editVoiceName.contains(".")) {
        editVoiceName = editVoiceName.split('.').first;
      }
      FileService.editFile(
        fileId: editFile.id ?? "",
        filename: editVoiceName,
      ).then((res) {
        if (res != null) {
          if (res.code != 200) {
            var message = res.msg;
            DialogHelper.showToastDialog(message);
          } else {
            var existVoice = voiceList.firstWhereOrNull(
              (voice) => voice.id == editFile.id,
            );
            if (existVoice != null) {
              existVoice.originalFilename = editVoiceName;
              appController.selectFileInfo.value.originalFilename =
                  editVoiceName; // 本地数据直接修改
              voiceList.refresh();
              appController.selectFileInfo.refresh();
              setShowVoiceList(
                folderId: appController.selectFolderFolder.value.id,
              );
              isMoreSelect.value = false;
              // 清空选中文件
              selectVoiceFileList.value = [];
            }
          }
        }
      });
    }
    NavigationUtils.back();
  }

  //删除音频
  Future<void> deleteVoice() async {
    if (selectVoiceFileList.isNotEmpty) {
      await EasyLoading.show();
      List<String> fildIdList =
          selectVoiceFileList.map((voice) => voice.id!).toList();
      await FolderService.deleteFile(fileIds: fildIdList, folderIds: []).then((
        res,
      ) {
        if (res != null) {
          if (res.code == 200) {
            for (var deleteItem in selectVoiceFileList) {
              voiceList.remove(deleteItem);
            }
            voiceList.refresh();
            setShowVoiceList(
              folderId: appController.selectFolderFolder.value.id,
            );
            DialogHelper.showToastDialog("deleteSuccessful");
            isMoreSelect.value = false;
          } else {
            var message = res.msg;
            DialogHelper.showToastDialog(message);
          }
        }
      });
      selectVoiceFileList.value = [];
      await EasyLoading.dismiss();
    }
  }

  //设置已读音频数据
  Future<void> readVoice(FileInfoModel voice) async {
    appController.selectFileInfo.value = voice;
    if (voice.isRead == 0) {
      await FileService.markRead(fileId: voice.id!).then((val) {
        if (val) {
          var existVoice = voiceList.firstWhereOrNull(
            (voiceItem) => voiceItem.id == voice.id,
          );
          if (existVoice != null) {
            existVoice.isRead = 1;
            voiceList.refresh();
            setShowVoiceList(
              folderId: appController.selectFolderFolder.value.id,
            );
          }
        }
      });
    }
  }

  //领取积分
  void bonusReceivePoint() {
    isReceive.value = 1;
    // TeamService.bonusReceive().then((val) {
    //   if (val != null) {
    //     if (val.code == 200) {
    //       DialogHelper.showToastDialog("pointReceived");
    //       PersonalService.getCurrentUserLoginInfo().then((val) {
    //         if (val != null) {
    //           isReceive.value = 1;
    //           appController.userInfo.value = val;
    //           appController.userInfo.refresh();
    //         }
    //       });
    //     } else {
    //       var message = val.msg;
    //       DialogHelper.showToastDialog(message);
    //     }
    //   }
    // });
  }

  //开始录音
  void startRecordingVoice() {
    if (appController.recordStatus.value == 1) {
      //正在录音 点击停止录音
      appController.stopRecord();
    } else {
      //开始录音
      appController
          .currentRecordingFileName
          .value = DateTimeHelper.dateTimeCoverTOString(DateTime.now());
      appController
          .startRecordTime
          .value = DateTimeHelper.dateTimeCoverTOString(DateTime.now());

      appController.startRecord();
    }
  }
}

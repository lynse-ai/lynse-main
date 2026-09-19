import 'dart:io';
import 'dart:math';

import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/model/file_model/file_management_model/upload_file_model.dart';
import 'package:dting/model/teams_model/members_model.dart';
import 'package:dting/model/teams_model/teams_model.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:dting/service/file_service.dart';
import 'package:dting/service/network_service.dart';
import 'package:dting/service/personal_service.dart';
import 'package:dting/service/team_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/datetime_helper.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/utils/local_sqldb.dart';
import 'package:dting/utils/oss_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

class TeamFileController extends GetxController {
  NetworkService get networkService => NetworkService.to;
  var appController = Get.find<DtingStore>();
  var homeController = Get.find<HomeIndexController>();

  var isMoreSelect = false.obs; //是否显示多选
  var selectVoiceFileList = <FileInfoModel>[].obs; //多选音频数据
  var voiceList = <FileInfoModel>[].obs; //Api返回的所有数据
  var currentTeam = TeamsModel.genDefault().obs; //当前显示团队
  var currentMemberList = <MembersModel>[].obs; //当前显示团队中的成员

  // var teamsList = <TeamsModel>[].obs; //当前用户的所有team

  // 待上传文件列表
  var uploadQueue = <Map<String, dynamic>>[].obs;
  var isUploadingQueue = false.obs;

  //所有默认头像
  List<String> defauleTeamUrl = [
    'assets/images_v3/team-avatar.png',
    'assets/images_v3/team-avatar2.png',
    'assets/images_v3/team-avatar3.png',
    'assets/images_v3/team-avatar4.png',
    'assets/images_v3/team-avatar5.png',
  ];
  TextEditingController createTeamController = TextEditingController(); //创建团队名称
  var createTeamAvatatUrl = "".obs; //当前的默认头像

  @override
  void onInit() {
    super.onInit();
    isMoreSelect = homeController.isMoreSelect;
    getAllTeamList();
    getCurrentTeamDetail();
    initVoiceListByTeamId();

    // 初始化网络监听
    _initNetworkMonitoring();
  }

  @override
  void onClose() {
    super.onClose();
  }

  // 重置数据
  void resetData() {
    selectVoiceFileList.value = [];
    voiceList.value = [];
    currentTeam.value = TeamsModel.genDefault();
    currentMemberList.value = [];
    isMoreSelect.value = false;
    // teamsList.value = [];
  }

  //获取团队数据
  Future<void> getAllTeamList() async {
    if (appController.teamsList.isEmpty) {
      await TeamService.getTeamListByUserId().then((val) {
        appController.teamsList.value = val;
      });
    }
  }

  void _initNetworkMonitoring() {
    // 监听网络连接恢复
    networkService.addOnConnectedCallback(() {
      print('网络已连接，开始处理待上传文件');

      if (isUploadingQueue.value) {
        print("正在上传，不用重复");
      } else {
        isUploadingQueue.value = true;
        _processUploadQueue();
      }
    });

    // 监听网络断开
    networkService.addOnDisconnectedCallback(() {
      print('网络已断开');
    });
  }

  //随机获取团队头像
  void getRandomAvatarUrl() {
    final random = Random();
    createTeamAvatatUrl.value =
        defauleTeamUrl[random.nextInt(defauleTeamUrl.length)];
  }

  //获取团队文件数据
  Future<void> initVoiceListByTeamId() async {
    isMoreSelect.value = false;
    selectVoiceFileList.value = [];
    var currentTeamId = appController.userInfo.value.teamId;
    if (currentTeamId != null) {
      await TeamService.getFileByTeamId(teamId: currentTeamId).then((val) {
        voiceList.value = val;
      });
    }
  }

  //获取团队信息
  Future<void> getCurrentTeamDetail() async {
    var currentTeamId = appController.userInfo.value.teamId;
    if (currentTeamId != null) {
      await TeamService.getTeamInfoByTeamId(teamId: currentTeamId).then((val) {
        if (val != null) {
          if (val.code == 200 && val.data != null) {
            currentTeam.value = TeamsModel.fromJson(val.data);
            if (currentTeam.value.members != null) {
              currentMemberList.value = currentTeam.value.members!;
            }
          } else {
            if (val.code == 2001) {
              currentTeam.value = TeamsModel.genDefault();
              //此团队不存在或者已被解散，请切换或者创建新的团队
              DialogHelper.showToastDialog("notExistsTeam");
            }
          }
        }
      });
    }
  }

  // //获取所有团队列表
  // Future<void> getAllTeamList() async {
  //   await TeamService.getTeamListByUserId().then((val) {
  //     teamsList.value = val;
  //   });
  // }

  //重命名团队文件
  void reNameForVoice({required String editVoiceName}) {
    var editFile = appController.selectFileInfo.value;

    if (editFile.id != null) {
      if (editVoiceName.contains(".")) {
        editVoiceName = editVoiceName.split('.').first;
      }
      TeamService.editFile(
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
              isMoreSelect.value = false;
              // 清空选中文件
              selectVoiceFileList.value = [];
            }
            Get.back();
          }
        }
      });
    }
  }

  //删除团队文件
  void deleteTeamsVoices() {
    // String? currentTeamId = LocalDataBase().basicBox!.get("currentTeamId");
    var currentTeamId = appController.userInfo.value.teamId;
    print('删除团队 deleteTeamsVoices currentTeamId =$currentTeamId');
    if (currentTeamId != null) {
      List<String> fileIdList =
          selectVoiceFileList.map((voice) => voice.id!).toList();
      TeamService.deleteTeamFileByTeamId(
        teamId: currentTeamId,
        fileIds: fileIdList,
      ).then((res) {
        print('删除团队 res $res');
        if (res != null) {
          if (res.code == 200) {
            for (var deleteItem in selectVoiceFileList) {
              voiceList.remove(deleteItem);
            }
            voiceList.refresh();
            selectVoiceFileList.value = [];
            isMoreSelect.value = false;
          } else {
            var message = res.msg;
            DialogHelper.showToastDialog(message);
          }
        }
      });
    }
  }

  //创建团队
  Future<Uint8List> loadAssetImage(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    return byteData.buffer.asUint8List();
  }

  //要先上传团队头像，拿到Url再创建团队
  Future<void> createNewTeam() async {
    isMoreSelect.value = false;
    selectVoiceFileList.value = [];
    if (createTeamController.text.trim().isEmpty) {
      DialogHelper.showToastDialog("cannotEmpty");
    } else {
      await EasyLoading.show();
      try {
        final Uint8List imageData = await loadAssetImage(
          createTeamAvatatUrl.value,
        );
        var uploadImage = await FileService.uploadAvatar(
          filename: "team-avatar.png",
          uploadPathBytes: imageData,
        );
        if (uploadImage != null) {
          await TeamService.createTeamByUser(
            avatarUrl: uploadImage,
            teamName: createTeamController.text,
          ).then((val) async {
            if (val != null) {
              if (val.code == 200) {
                appController.getAllTeamList();
                PersonalService.getCurrentUserLoginInfo().then((user) async {
                  if (user != null) {
                    appController.userInfo.value = user;
                    await refreshTeamData();
                    await EasyLoading.dismiss();
                  }
                });
              } else {
                DialogHelper.showToastDialog(val.msg);
                await EasyLoading.dismiss();
              }
            }
            Get.back();
          });
        } else {
          DialogHelper.showToastDialog("createFail");
        }
      } catch (e) {
        await EasyLoading.dismiss();

        DialogHelper.showToastDialog("createFail");
      }
    }
  }

  //导入手机本地音频
  Future<void> importVoiceByPhone() async {
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

  //切换成选中的团队
  Future<void> changeToSelectTeam({required TeamsModel selectTeam}) async {
    isMoreSelect.value = false;
    selectVoiceFileList.value = [];
    await EasyLoading.show();
    try {
      TeamService.changeTeam(teamId: selectTeam.id).then((val) async {
        if (val) {
          LocalDataBase.setCache(currentTeamId: selectTeam.id);
          appController.userInfo.value.teamId = selectTeam.id;
          appController.userInfo.refresh();
          await refreshTeamData();
          await EasyLoading.dismiss();
          Get.back();
        } else {
          DialogHelper.showToastDialog("changeTeamFail");
        }
      });
    } catch (e) {
      await EasyLoading.dismiss();
    }
  }

  //刷新新团队数据
  Future<void> refreshTeamData() async {
    // 刷新文件列表（仅在有网络时才刷新）
    if (networkService.isConnected.value) {
      getCurrentTeamDetail();
      initVoiceListByTeamId();
    }
  }

  //邀请新成员
  Future<void> inviteMemberJoinOurTeam({
    required List<String> inviteePhoneList,
    bool back = true,
  }) async {
    await EasyLoading.show();
    try {
      if (currentTeam.value.id != "-1" && inviteePhoneList.isNotEmpty) {
        TeamService.postInvite(
          teamId: currentTeam.value.id,
          inviteePhoneList: inviteePhoneList,
        ).then((invite) async {
          if (invite != null) {
            if (invite.code == 200) {
              getCurrentTeamDetail();
              Get.back();
              DialogHelper.showToastDialog("inviteSuccessful");
            } else {
              var message = invite.msg;
              DialogHelper.showToastDialog(message);
            }
            await EasyLoading.dismiss();
          }
        });
      }
    } catch (e) {
      await EasyLoading.dismiss();
    }
  }

  //===========================================断网上传===========================================

  //上传音频文件
  updateFileByOss({
    required String multiFilePath,
    required int fileSize,
    int? fileDuration,
    String? saveFileName,
  }) async {
    if (multiFilePath.isNotEmpty) {
      final audioPlayer = AudioPlayer();
      await audioPlayer.setFilePath(multiFilePath);
      print("----updateFileByOss 音频文件大小  $fileSize");
      print("----updateFileByOss 音频文件时长fileDuration  $fileDuration");

      // 录音卡上传则传递fileDuration参数，本地文件则直接获取音频文件的duration作为时长
      int time = 0;
      if (fileDuration != null) {
        time = fileDuration;
      } else if (audioPlayer.duration != null) {
        time = DateTimeHelper.convertDurationTransSecond(audioPlayer.duration!);
      }
      print("----updateFileByOss 音频文件时长  $time");

      var teamId = appController.userInfo.value.teamId;

      //以上是设置saveFileName
      UploadFileModel uploadForOss = UploadFileModel(
        customerId: appController.userInfo.value.id,
        teamId: teamId,
        path: multiFilePath,
        macAddress: appController.connectingDevice.value.macAddress ?? "",
        location: appController.location.value,
        saveFilename: saveFileName,
        bizDuration: time,
        mode: "IMPORT",
        fileSize: fileSize,
        recordStartTime: appController.startRecordTime.value,
        scene: -1,
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
  }

  // 加载待上传队列
  Future<void> loadUploadQueue() async {
    try {
      // 只加载待上传、上传中、上传失败的文件，不包括已成功上传的
      final queue = await SqlDBHelper.getDisplayUploadQueue(
        teamId: appController.userInfo.value.teamId,
      );
      uploadQueue.value = queue;
      print('加载待上传队列: ${queue.length} 个文件');
    } catch (e) {
      print('加载待上传队列失败: $e');
    }
  }

  // 处理待上传队列
  Future<void> _processUploadQueue() async {
    if (isUploadingQueue.value) return;

    isUploadingQueue.value = true;

    try {
      final pendingUploads = await SqlDBHelper.getPendingUploads();
      print('开始处理待上传文件: ${pendingUploads.length} 个');

      for (final uploadData in pendingUploads) {
        if (!networkService.isConnected.value) {
          print('网络断开，停止上传队列处理');
          break;
        }

        final uploadFile = _mapToUploadFileModel(uploadData);
        final id = uploadData['id'] as int;

        try {
          // 更新状态为上传中
          await SqlDBHelper.updateUploadStatus(id, 1);
          await loadUploadQueue();

          // 执行上传
          final fileId = await OssUtilsService().upload(updateFile: uploadFile);

          if (fileId != null) {
            // 上传成功
            await FileService.uploadOssSuccnotify(fileId: fileId);
            await SqlDBHelper.updateUploadStatus(id, 2);

            // 延迟后删除成功的记录
            // Future.delayed(Duration(seconds: 2), () async {
            await SqlDBHelper.removeUploadedFile(id);
            await loadUploadQueue();
            // });

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
        }

        await loadUploadQueue();

        // 短暂延迟避免过于频繁的请求
        await Future.delayed(Duration(milliseconds: 500));
      }

      // 刷新文件列表（仅在有网络时才刷新）
      if (networkService.isConnected.value) {
        await initVoiceListByTeamId();
      }
    } catch (e) {
      print('处理上传队列异常: $e');
    } finally {
      isUploadingQueue.value = false;
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

    final queue = await SqlDBHelper.getDisplayUploadQueue(
      teamId: appController.userInfo.value.teamId,
    );
    final uploadData = queue.firstWhere((item) => item['id'] == id);

    if (uploadData != null) {
      final uploadFile = _mapToUploadFileModel(uploadData);

      try {
        await SqlDBHelper.updateUploadStatus(id, 1);
        await loadUploadQueue();

        final fileId = await OssUtilsService().upload(updateFile: uploadFile);

        if (fileId != null) {
          await FileService.uploadOssSuccnotify(fileId: fileId);
          await SqlDBHelper.updateUploadStatus(id, 2);

          Future.delayed(Duration(seconds: 2), () async {
            await SqlDBHelper.removeUploadedFile(id);
            await loadUploadQueue();
          });

          print('团队文件上传成功');
          // 刷新文件列表（仅在有网络时才刷新）
          if (networkService.isConnected.value) {
            await initVoiceListByTeamId();
          }
        } else {
          await SqlDBHelper.updateUploadStatus(
            id,
            3,
            errorMessage: '上传返回空文件ID',
          );
          print('团队文件上传成功');
        }
      } catch (e) {
        await SqlDBHelper.updateUploadStatus(id, 3, errorMessage: e.toString());
        print('团队文件上传成功: $e');
      }

      await loadUploadQueue();
    }
  }

  // 删除待上传文件
  Future<void> removeFromUploadQueue(int id) async {
    await SqlDBHelper.removeUploadedFile(id);
    await loadUploadQueue();
  }

  //===========================================断网上传===========================================
}

import 'dart:async';
import 'dart:math';

import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/model/file_model/file_processing_model/outline_model.dart';
import 'package:dting/model/file_model/file_processing_model/summary_model.dart';
import 'package:dting/model/file_model/file_processing_model/trans_model.dart';
import 'package:dting/model/teams_model/response_share_team_model.dart';
import 'package:dting/model/teams_model/teams_model.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/service/file_service.dart';
import 'package:dting/service/folder_service.dart';
import 'package:dting/service/personal_service.dart';
import 'package:dting/service/team_service.dart';
import 'package:dting/service/translate_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/logger_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:logger/logger.dart';

class VoiceDetailsController extends GetxController
    with GetSingleTickerProviderStateMixin {
  var appController = Get.find<DtingStore>();
  var teamFileController = Get.find<TeamFileController>();
  var homeController = Get.find<HomeIndexController>();

  var selectAIMenu = 2.obs; //控制AI 菜单
  var currentVoiceFile = ResponseShareTeamModel.genDefault().obs; //移动文件夹之后的返回数据

  //播放音频
  var showBoxPlayVoice = false.obs;
  var openSetting = false.obs; //是否打开设置
  var speedTip = "1.0x".obs; //设置音频播放速度
  late AudioPlayer audioPlayer = AudioPlayer();
  var ossVoiceUrl = "".obs; //从云端获取的可播放的音频数据
  var playerState = "stopped".obs; //控制音频播放状态

  var playDuration = Duration(microseconds: 100).obs;
  var allTime = 0.obs; //音频所有时长
  var currentPlayTime = 0.obs; //音频当前播放时长
  var enablePlay = false.obs; //当文件损毁时不允许滑动Slider
  var sliderValue = 0.0.obs;

  //转写音频数据
  late AnimationController sliderController;
  var transcrSpeakList = <TransModel>[].obs; //转写源数据

  var conclData = SummaryModel().obs;
  var outlnData = OutLineModel().obs;
  var haveMindMapData = true.obs;
  //没有积分
  var teamEqota = true.obs;
  var eqotaPoint = "".obs;

  void sliderValueListener() {
    sliderValue.value = sliderController.value;
  }

  var transLoading = false.obs; //trans没有数据时出现loading
  var concelLoading = false.obs; //concel没有数据时出现loading
  var outlnLoading = false.obs; //outln没有数据时出现loading
  var mindmapLoading = false.obs; //mindmap没有数据时出现loading

  //分享到团队
  // var teamsList = <TeamsModel>[].obs; //所有的团队
  var isPersonalFile = true.obs; //判断是团队文件还是个人文件

  /// 查询转录语言列表

  @override
  void onInit() {
    super.onInit();
    getAllTeamList();
    //全局使用currentVoiceFile.value.fileId、以及teamId来进行API功能的使用
    // try {
    currentVoiceFile.value.fileId = appController.selectFileInfo.value.id ?? "";
    currentVoiceFile.value.teamId = appController.userInfo.value.teamId ?? "";
    //
    isPersonalFile.value = (Get.arguments['isPersonalFile']);
    appController.eqota.value = false;
    initFileInfo();
    initOssVoiceUrl();
    sliderController = AnimationController(
      duration: Duration(
        seconds: appController.selectFileInfo.value.bizDuration ?? 0,
      ),
      vsync: this,
    );
    sliderController.addListener(sliderValueListener);

    if (appController.selectFileInfo.value.transcribeTaskId != null) {
      initAI();
    }
  }

  @override
  void dispose() {
    super.dispose();
    audioPlayer.dispose();
  }

  @override
  void onClose() {
    print('播放详情页销毁关闭了');

    //清除音频数据
    playerState.value = "stopped";
    appController.isPlay.value = false;
    audioPlayer.stop();
    audioPlayer.dispose();

    EasyLoading.dismiss();
    if (sliderController.isAnimating) {
      sliderController.stop();
      sliderController.dispose();
    }
    sliderController.removeListener(sliderValueListener);
    // Get.delete<TableViewController>();
    transLoading.value = false;
    concelLoading.value = false;
    outlnLoading.value = false;
    mindmapLoading.value = false;
    super.onClose();
  }

  /// 已经发起了转写任务，需要循环查询生成状态
  Timer? timer;
  void loopRefreshStatus({
    required String taskId,
    required String aiTaskType,
  }) async {
    // 首先取消可能存在的旧计时器
    timer?.cancel();

    // 创建新的计时器，每隔5秒执行一次
    timer = Timer.periodic(Duration(seconds: 5), (timer) async {
      final taskStatus = await FileService.getAiTaskStatus(
        fileId: currentVoiceFile.value.fileId,
        taskId: taskId,
        aiTaskType: aiTaskType,
      );

      // 检查任务状态
      if (taskStatus != AiTaskStatus.RUNNING) {
        // 任务不再运行，取消计时器并刷新数据
        timer.cancel();
        if (aiTaskType == ProcessType.CONCLUSION.name) {
          getConcelData();
        } else {
          getOutlnData();
        }
      }
      // 如果任务仍然在运行，不需要做任何事情，计时器会在5秒后再次触发
    });
  }

  //重置数据
  void resetData() {
    transcrSpeakList.clear();
    conclData.value = SummaryModel();
    outlnData.value = OutLineModel();
    // mindMapData.value = MindMapModel();
    selectAIMenu.value = 2;
    openSetting.value = false;
    playerState.value = "stopped";
    enablePlay.value = false;
    sliderValue.value = 0.0;
    currentPlayTime.value = 0;
    appController.isPlay.value = false;
    isPersonalFile.value = true;
    transLoading.value = true;
    concelLoading.value = true;
    outlnLoading.value = true;
    mindmapLoading.value = true;
  }

  //获取团队数据
  Future<void> getAllTeamList() async {
    if (appController.teamsList.isEmpty) {
      await TeamService.getTeamListByUserId().then((val) {
        appController.teamsList.value = val;
      });
    }
  }

  //拿到本条音频在OSS的URL用于播放音频
  void initOssVoiceUrl() {
    var fileSourceTypeString = "TEAM";
    if (isPersonalFile.value) {
      fileSourceTypeString = "PERSONAL";
    }

    FileService.downloadFile(
      fileId: currentVoiceFile.value.fileId,
      localSavePath: appController.selectFileInfo.value.url,
      sourceType: fileSourceTypeString,
    ).then((res) async {
      if (res != null && res.data != null) {
        ossVoiceUrl.value = res.data;
      }
    });
  }

  //查询当前音频详情
  Future<void> initFileInfo() async {
    if (homeController.bottomMenuIndex.value == 0 &&
        currentVoiceFile.value.fileId ==
            appController.selectFileInfo.value.id) {
      await FileService.fileDetail(fileId: currentVoiceFile.value.fileId).then((
        val,
      ) {
        if (val != null) {
          LoggerUtils.d('initFileInfo = ${val.toJson()}');
          appController.selectFileInfo.value = val;
          //更新录音卡片标签

          for (var voice in homeController.voiceList) {
            if (voice.id == val.id) {
              // e.transcribeTaskId = val.transcribeTaskId;
              // e.conclusionId = val.conclusionId;
              // e.outlineId = val.outlineId;
              // e.mindMapId = val.mindMapId;
              voice.transcribeTaskId = val.transcribeTaskId;
              voice.originalFilename = val.originalFilename;
              // voice = val;
            }
          }
          homeController.voiceList.refresh();
          homeController.setShowVoiceList(
            folderId: appController.selectFolderFolder.value.id,
          );
        }
      });
    } else {
      // String? currentTeamId = LocalDataBase().basicBox!.get("currentTeamId");

      await TeamService.getFileInfoByTeamId(
        fileId: currentVoiceFile.value.fileId,
        teamId: currentVoiceFile.value.teamId,
      ).then((val) {
        if (val != null) {
          LoggerUtils.d('getFileInfoByTeamId = ${val.toJson()}');
          appController.selectFileInfo.value = val;
          //更新录音卡片标签
          for (var e in teamFileController.voiceList) {
            if (e.id == val.id) {
              // e = val;
              e.originalFilename = val.originalFilename;
              e.transcribeTaskId = val.transcribeTaskId;
              // e.conclusionId = val.conclusionId;
              // e.outlineId = val.outlineId;
              // e.mindMapId = val.mindMapId;
            }
          }
          teamFileController.voiceList.refresh();
        }
      });
    }
  }

  //删除团队音频还是团队音频
  void deletePsonalOrTeamVoice() {
    if (homeController.bottomMenuIndex.value == 0 &&
        currentVoiceFile.value.fileId ==
            appController.selectFileInfo.value.id) {
      deletePersonalVoice();
    } else {
      deleteTeamsVoices();
    }
  }

  //删除个人音频文件
  Future<void> deletePersonalVoice() async {
    await EasyLoading.show();

    try {
      final res = await FolderService.deleteFile(
        fileIds: [currentVoiceFile.value.fileId],
        folderIds: [],
      );

      if (res != null) {
        if (res.code == 200 && res.data != null) {
          appController.selectFileInfo.value = FileInfoModel();
          Get.back();
        } else {
          var message = res.msg;
          DialogHelper.showToastDialog(message);
        }
      }
    } catch (e) {
      print("deleteVoice error: $e");
    } finally {
      await EasyLoading.dismiss();
      // 刷新首页音频列表数据
      homeController.initVoiceList();
    }
  }

  //删除团队音频文件
  Future<void> deleteTeamsVoices() async {
    await EasyLoading.show();
    try {
      print(
        '删除团队 deleteTeamsVoices currentTeamId =${currentVoiceFile.value.teamId}',
      );

      TeamService.deleteTeamFileByTeamId(
        teamId: currentVoiceFile.value.teamId,
        fileIds: [currentVoiceFile.value.fileId],
      ).then((res) {
        print('删除团队 res $res');
        if (res != null) {
          if (res.code == 200) {
            appController.selectFileInfo.value = FileInfoModel();
            Get.back();
          } else {
            var message = res.msg;
            DialogHelper.showToastDialog(message);
          }
        }
      });
    } catch (e) {
      print("deleteVoice error: $e");
    } finally {
      await EasyLoading.dismiss();
      // 刷新团队音频列表数据
      teamFileController.initVoiceListByTeamId();
    }
  }

  //重命名当前文件
  void reNameFile(String editText) {
    if (homeController.bottomMenuIndex.value == 0 &&
        currentVoiceFile.value.fileId ==
            appController.selectFileInfo.value.id) {
      homeController.reNameForVoice(editVoiceName: editText);
    } else {
      teamFileController.reNameForVoice(editVoiceName: editText);
    }
  }

  // 倒计时相关变量
  // 进度相关变量
  Timer? _progressTimer;

  /// 启动递增进度
  void startProgress() {
    // 停止之前的进度
    if (_progressTimer?.isActive ?? false) {
      _progressTimer?.cancel();
    }

    if (currentPlayTime.value >=
        appController.selectFileInfo.value.bizDuration!) {
      currentPlayTime.value = appController.selectFileInfo.value.bizDuration!;
      return;
    }

    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      currentPlayTime.value = currentPlayTime.value + 1;
      if (currentPlayTime.value >=
          appController.selectFileInfo.value.bizDuration!) {
        timer.cancel();
        currentPlayTime.value = appController.selectFileInfo.value.bizDuration!;
        //结束录音，更改状态
        playerState.value = "completed";
        appController.isPlay.value = false;
      }
    });
  }

  //点击AI功能按钮
  Future<void> getTransResponse(String templateId) async {
    transLoading.value = true;
    concelLoading.value = true;
    outlnLoading.value = true;
    mindmapLoading.value = true;
    try {
      var tempTeamId = "";
      if (homeController.bottomMenuIndex.value == 1) {
        tempTeamId = currentVoiceFile.value.teamId;
      }
      await FileService.transResponse(
        fileId: currentVoiceFile.value.fileId,
        teamId: tempTeamId,
        templateId: templateId,
      ).then((res) async {
        if (res != null) {
          if (res.code == 200 && res.data != null) {
            final taskId = res.data["taskId"]?.toString();
            final requiredPoints = res.data["requiredPoints"] ?? 0;

            appController.selectFileInfo.update((fileInfo) {
              fileInfo?.transcribeTaskId = taskId;
              fileInfo?.requiredPoints = requiredPoints;
            });
            //首页个人数据
            if (homeController.bottomMenuIndex.value == 0) {
              var exist = homeController.voiceList.firstWhereOrNull(
                (file) => file.id == appController.selectFileInfo.value.id,
              );
              if (exist != null) {
                exist.transcribeTaskId = taskId;
              }
              homeController.voiceList.refresh();
            } else {
              //团队数据
              var exist = teamFileController.voiceList.firstWhereOrNull(
                (file) => file.id == appController.selectFileInfo.value.id,
              );
              if (exist != null) {
                exist.transcribeTaskId = taskId;
              }
              teamFileController.voiceList.refresh();
            }
            appController.selectFileInfo.refresh();
            DialogHelper.showToastDialog(
              "payPointTip".trParams({'point': requiredPoints.toString()}),
            );
            initAI();
          } else {
            if (res.code == 402) {
              LoggerUtils.d("没有转写时长了....${res.msg}");
              //转写时长已经使用完
              appController.eqota.value = true;
              teamEqota.value = true;
              //预计消耗多少积分
              var point = res.data["requiredPoints"];
              eqotaPoint.value = point.toString();
            } else {
              appController.eqota.value = false;
              LoggerUtils.d("appController.eqota.value = false ");
              var message = res.msg;
              DialogHelper.showToastDialog(message);
              // print("没有转写时长了。。。。。" + message);
            }
            transLoading.value = false;
            concelLoading.value = false;
            outlnLoading.value = false;
            mindmapLoading.value = false;
          }
        }
      });
    } catch (error) {
      transLoading.value = false;
      concelLoading.value = false;
      outlnLoading.value = false;
      mindmapLoading.value = false;
      print(error);
    }
  }

  //概括接口
  Future<void> getConcelData({bool showMessage = false}) async {
    var tempTeamId = "";
    if (homeController.bottomMenuIndex.value == 1) {
      tempTeamId = currentVoiceFile.value.teamId;
    }
    await FileService.getConclusion(
      fileId: currentVoiceFile.value.fileId,
      teamId: tempTeamId,
    ).then((val) async {
      if (val != null) {
        if (val.code == 200) {
          // 响应为空的时候，提示正在生成中...
          if (val.data == null) {
            concelLoading.value = false;
            mindmapLoading.value = false;
            return;
          }

          conclData.value = SummaryModel.fromJson(val.data);
          // 如果againTaskId不为空，则再查询AI任务状态
          final String? againTaskId = conclData.value.againTaskId;
          if (againTaskId != null) {
            final taskStatus = await FileService.getAiTaskStatus(
              fileId: currentVoiceFile.value.fileId,
              taskId: againTaskId,
              aiTaskType: ProcessType.CONCLUSION.name,
            );
            concelLoading.value = taskStatus == AiTaskStatus.RUNNING;
          } else {
            concelLoading.value = false;
          }

          if (conclData.value.conclusionText != null &&
              !conclData.value.conclusionText!.contains("无需生成总结")) {
            initWebview('''
               --- markmap:
                 maxWidth: 480
                 initialExpandLevel: 4
               ---\r\n${conclData.value.conclusionText!}''');
          } else {
            mindmapLoading.value = false;
            haveMindMapData.value = false;
          }
        } else if (val.code == 1001) {
          concelLoading.value = true;
          if (showMessage) {
            // var message = val.msg;
            // DialogHelper.showToastDialog("handler");
          }
        } else {
          if (showMessage) {
            var message = val.msg;
            DialogHelper.showToastDialog(message);
          }
          concelLoading.value = false;
        }
      }
    });
  }

  //转写接口
  Future<void> getTransData() async {
    var tempTeamId = "";
    if (homeController.bottomMenuIndex.value == 1) {
      tempTeamId = currentVoiceFile.value.teamId;
    }
    await FileService.getTrans(
      taskId: appController.selectFileInfo.value.transcribeTaskId!,
      teamId: tempTeamId,
      fileId: currentVoiceFile.value.fileId,
    ).then((val) async {
      if (val != null) {
        if (val.code == 200) {
          if (val.data == null) {
            transLoading.value = false;
            return;
          }
          if (homeController.bottomMenuIndex.value == 0 &&
              currentVoiceFile.value.fileId ==
                  appController.selectFileInfo.value.id) {
            //刷新个人积分
            PersonalService.getCurrentUserLoginInfo().then((user) {
              if (user != null) {
                appController.userInfo.value = user;
              }
            });
            for (var e in homeController.voiceList) {
              if (e.id == currentVoiceFile.value.fileId) {
                e.transcribeTaskId =
                    appController.selectFileInfo.value.transcribeTaskId;
              }
            }
            homeController.voiceList.refresh();
          } else {
            //团队刷新

            TeamService.getTeamListByUserId().then((val) {
              appController.teamsList.value = val;
              var isExist = val.firstWhereOrNull(
                (team) => team.id == teamFileController.currentTeam.value.id,
              );
              if (isExist != null) {
                // teamFileController.currentTeam.value = isExist;
                teamFileController.getCurrentTeamDetail();
              }
            });
            for (var e in teamFileController.voiceList) {
              if (e.id == currentVoiceFile.value.fileId) {
                // e=val;
                e.transcribeTaskId =
                    appController.selectFileInfo.value.transcribeTaskId;
              }
            }
            teamFileController.voiceList.refresh();
          }

          transcrSpeakList.value = List<TransModel>.from(
            val.data.map((x) => TransModel.fromJson(x)),
          );
          transLoading.value = false;
        } else if (val.code == 1001) {
          transLoading.value = true;
          // var message = val.msg;
          // DialogHelper.showToastDialog("handler");
        } else {
          var message = val.msg;
          DialogHelper.showToastDialog(message);
          transLoading.value = false;
        }
      }
    });
  }

  //总结接口
  Future<void> getOutlnData({bool showMessage = false}) async {
    var tempTeamId = "";
    if (homeController.bottomMenuIndex.value == 1) {
      tempTeamId = currentVoiceFile.value.teamId;
    }
    await FileService.getOutline(
      fileId: currentVoiceFile.value.fileId,
      teamId: tempTeamId,
    ).then((val) async {
      if (val != null) {
        if (val.code == 200) {
          if (val.data == null) {
            outlnLoading.value = false;
            return;
          }
          outlnData.value = OutLineModel.fromJson(val.data);
          // 如果againTaskId不为空，则再查询AI任务状态
          final String? againTaskId = outlnData.value.againTaskId;
          if (againTaskId != null) {
            final taskStatus = await FileService.getAiTaskStatus(
              fileId: currentVoiceFile.value.fileId,
              taskId: againTaskId,
              aiTaskType: ProcessType.CONCLUSION.name,
            );
            outlnLoading.value = taskStatus == AiTaskStatus.RUNNING;
          } else {
            outlnLoading.value = false;
          }

          initFileInfo();
        } else if (val.code == 1001) {
          outlnLoading.value = true;
          // if (showMessage) {
          //   var message = val.msg;
          //   DialogHelper.showToastDialog("handler");
          // }
        } else {
          if (showMessage) {
            var message = val.msg;
            DialogHelper.showToastDialog(message);
          }
          outlnLoading.value = false;
        }
      }
    });
  }

  //获取AI数据
  Future<void> initAI() async {
    transLoading.value = true;
    concelLoading.value = true;
    outlnLoading.value = true;
    mindmapLoading.value = true;
    await getTransData();
    // await getMindMapData();
    await getConcelData();
    await getOutlnData();
  }

  //判断当前AI菜单，请求相应的数据
  void switchAIResponse() {
    if (appController.selectFileInfo.value.transcribeTaskId != null) {
      switch (selectAIMenu.value) {
        case 0:
          print("概要");
          getOutlnData(showMessage: true);
          break;
        case 1:
          print("转写");
          getTransData();
          break;
        case 2:
          print("总结");
          getConcelData(showMessage: true);
          break;
        default:
          print("思维导图");
          // getMindMapData(showMessage: true);
          getConcelData(showMessage: true);
          break;
      }
    }
  }

  //音频播放
  Future<void> voicePlay() async {
    if (playerState.value == "playing") {
      playerState.value = "paused";
      appController.isPlay.value = false;
      audioPlayer.pause();
      sliderController.stop();
    } else if (playerState.value == "paused") {
      playerState.value = "playing";
      appController.isPlay.value = true;
      audioPlayer.seek(Duration(seconds: currentPlayTime.value));
      audioPlayer.play();
      sliderController.forward();
    } else if (playerState.value == "stopped" ||
        playerState.value == "completed") {
      if (playerState.value == "completed") {
        sliderValue.value = 0.0;
        currentPlayTime.value = 0;
        sliderController.value = 0.0;
        sliderController.reset();
        sliderController.forward();
      }
      playerState.value = "playing";
      appController.isPlay.value = true;
      if (ossVoiceUrl.value.isNotEmpty) {
        try {
          await audioPlayer.setUrl(ossVoiceUrl.value);
          audioPlayer.seek(Duration(seconds: currentPlayTime.value));
          audioPlayer.play();
          // 重新监听 positionStream
          try {
            var alltimeByAudio = appController.selectFileInfo.value.bizDuration;
            if (alltimeByAudio != null) {
              // _positionSub =
              // audioPlayer.positionStream.listen((position) {
              //   currentPlayTime.value = position.inSeconds;
              //   print("当前播放时长： ${currentPlayTime.value} position = ${position.toString()}");
              // });

              startProgress();
              // currentPlayTime.value = countdownText.value;
            }
          } catch (e) {
            enablePlay.value = true; //不允许滑动进度条
            currentPlayTime.value = 0;
            openSetting.value = false;
            appController.isPlay.value = false;
            playerState.value = "stopped";
            DialogHelper.showToastDialog("corruptedFile");
          }
          // sliderController.reset();
          sliderController.forward();
        } catch (e) {
          enablePlay.value = true; //不允许滑动进度条

          currentPlayTime.value = 0;
          openSetting.value = false;
          appController.isPlay.value = false;
          // playProgress.value = 0.0;
          playerState.value = "stopped";
          DialogHelper.showToastDialog("corruptedFile");
          print('audioPlayer.play error: $e');
          return;
        }

        var allDuration = audioPlayer.duration;
        if (allDuration != null) {
          allTime.value = allDuration.inSeconds;
        }
        print('allTime: ${playDuration.value}'); // 输出音频时长
      } else {
        initOssVoiceUrl();
        DialogHelper.showToastDialog("corruptedFile");
      }
    }
  }

  //滑动进度条
  void slidePlayProgress(double value) {
    if (playerState.value == "playing") {
      sliderController.forward();
    } else if (playerState.value == "paused") {
      sliderController.stop();
    } else if (playerState.value == "stopped" ||
        playerState.value == "completed") {
      sliderController.stop();
    }
    currentPlayTime.value =
        (value * appController.selectFileInfo.value.bizDuration!.toInt())
            .toInt();
    sliderController.value = value;
    audioPlayer.seek(Duration(seconds: currentPlayTime.value));
    startProgress();
  }

  //快进
  void fastForward() {
    currentPlayTime.value = min(
      currentPlayTime.value + 15,
      appController.selectFileInfo.value.bizDuration!,
    );
    final newPosition = Duration(seconds: currentPlayTime.value);
    audioPlayer.seek(newPosition);
    startProgress();
    //需要添加一个动画也相应的改动
    var sliderValues =
        newPosition.inSeconds / appController.selectFileInfo.value.bizDuration!;
    sliderController.value = sliderValues;
    if (playerState.value == "playing") {
      sliderController.forward();
    } else {
      sliderController.stop();
    }
  }

  //回退
  void fastRewind() {
    currentPlayTime.value = max(0, currentPlayTime.value - 15);
    final newPosition = Duration(seconds: currentPlayTime.value);
    audioPlayer.seek(newPosition);
    startProgress();
    //需要添加一个动画也相应的改动
    var sliderValues =
        newPosition.inSeconds / appController.selectFileInfo.value.bizDuration!;
    sliderController.value = sliderValues;
    if (playerState.value == "playing") {
      sliderController.forward();
    } else {
      sliderController.stop();
    }
  }

  //思维导图
  WebViewController webViewController =
      WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(ColorUtil.fromHexString("#FFFFFF"))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              print("WebView Page finished loaded: $url");
            },
            onWebResourceError: (WebResourceError error) {
              print(
                "WebView Page error: ${error.errorCode} ${error.description}",
              );
            },
          ),
        )
        ..addJavaScriptChannel(
          'WebViewBridge',
          onMessageReceived: (JavaScriptMessage message) {
            print("WebView message: ${message.message}");
          },
        )
        // 为Android添加缩放控制支持
        ..enableZoom(true);

  void initWebview(String mindString) async {
    Logger().i("$mindString");
    String htmlString = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes, minimum-scale=0.1, maximum-scale=10.0" />
        <title>Mindmap</title> 
        <style>
        html, body {
          margin: 0;
          padding: 0;
          height: 100%;
          width: 100%;
          background-color: transparent;
        }

        .markmap {
          position: relative;
          height: 100%; 
          width: 100%;
         background-color: transparent;
        }

        svg.markmap {
          width: 100%;
          height: 100%;
        }
        </style>

        <script>
        window.markmap = {
          autoLoader: { manual: true },
        };
        </script>
        <!-- 引入插件 -->
        <script src="https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js"></script>
        <!-- 引入markmap.js -->
        <script src="https://cdn.jsdelivr.net/npm/markmap-autoloader@latest"></script>

        <script>
        setTimeout(() => {
          markmap.autoLoader.renderAll();
        }, 1800);  
        </script>
      </head>
      <body>
        <div style="display:none; " id="base64Container"></div>

        <!-- markdown mindmap容器 -->
        <div class="markmap" id="markmap">
          <!-- markdown数据内容 -->
          <script type="text/template">
            $mindString
          </script>
        </div>
      </body>
      </html>
    ''';
    webViewController.loadHtmlString(htmlString);
    mindmapLoading.value = false;
  }

  Future<String> exportImage({type = 'png'}) async {
    try {
      String buildImgScript = '''
        try {
          const _svg = document.querySelector('#markmap');
          html2canvas(_svg).then((canvas) => {
            const svgData = canvas.toDataURL('image/png');
            document.getElementById('base64Container').innerText = svgData;
          });
        } catch (error) {
          console.error('SVG转换为图片失败, ' + error);
        };
      ''';

      await webViewController.runJavaScript(buildImgScript);

      await Future.delayed(const Duration(seconds: 1));
      String imgData =
          await webViewController.runJavaScriptReturningResult(
                '''document.getElementById('base64Container').innerText''',
              )
              as String;
      // print('===controller imgData: $imgData');
      return imgData.split('base64,').last;
    } catch (e) {
      print('---Error exporting image: $e');
      return '';
    }
  }

  //移动音频文件并且数据刷新
  void copyOrMoveFileList({
    required bool copyOrMove,
    required bool isPersonal,
    required List<TeamsModel> selectTeamList,
  }) {
    List<String> teamTeamList = [];
    for (var team in selectTeamList) {
      teamTeamList.add(team.id);
    }
    if (teamTeamList.isEmpty) {
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
        fileIds: [currentVoiceFile.value.fileId],
        actionType: "COPY",
        teamIds: teamTeamList,
        sourceType: fileSourceTypeString,
      ).then((val) {
        if (val != null) {
          if (val.code == 200) {
            Get.back();
            if (!isPersonal) {
              //团队数据刷新
              teamFileController.initVoiceListByTeamId();
            } else {
              //个人数据刷新
              homeController.initVoiceList();
            }
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
        fileIds: [currentVoiceFile.value.fileId],
        actionType: "MOVE",
        teamIds: teamTeamList,
        sourceType: fileSourceTypeString,
      ).then((val) {
        if (val != null) {
          if (val.code == 200 && val.data != null) {
            Get.back();
            var returnData = List<ResponseShareTeamModel>.from(
              val.data.map((x) => ResponseShareTeamModel.fromJson(x)),
            );

            if (returnData.isNotEmpty) {
              //如果这个数据不是空，那么就更新当前界面的fileID、teamID
              currentVoiceFile.value.fileId = returnData.first.fileId;
              currentVoiceFile.value.teamId = returnData.first.teamId;
            }

            if (isPersonal) {
              //个人数据刷新
              homeController.initVoiceList();
            } else {
              //团队数据刷新
              teamFileController.initVoiceListByTeamId();
            }
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

import 'package:dting/pages/device/audio_sure/audio_sure_page.dart';
import 'package:dting/pages/device/menu/concel/concel_page.dart';
import 'package:dting/pages/device/menu/mind/mind_page.dart';
import 'package:dting/pages/device/menu/outIn/outIn_page.dart';
import 'package:dting/pages/device/menu/trans/trans_page.dart';
import 'package:dting/pages/device/voice_details/more_operations.dart';
import 'package:dting/pages/device/widget/audio_waveform_slider.dart';
import 'package:dting/pages/device/widget/eqota_widget.dart';
import 'package:dting/pages/home/folder_manage/widget/edit_text_widget.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/datetime_helper.dart';
import 'package:dting/utils/logger_utils.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/Icon_gestureDetector.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'voicedetails_controller.dart';

class VoiceDetailsPage extends GetView<VoiceDetailsController> {
  const VoiceDetailsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopScope(
        canPop: true, // 拦截返回
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            controller.onClose();
            Get.back();
          }
        },
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.delta.dy < 0) {
              controller.showBoxPlayVoice.value = false;
            }
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
            body: SafeArea(
              top: false,
              bottom: false,
              child: Stack(
                alignment: Alignment.center,
                children: [_contentWidget(), _eqotaWidget()],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _eqotaWidget() {
    final fileInfo = controller.appController.selectFileInfo.value;
    final hasNoTask = fileInfo.transcribeTaskId == null;
    final isEqotaEnabled = controller.appController.eqota.value;
    LoggerUtils.d("hasNoTask: $hasNoTask, isEqotaEnabled: $isEqotaEnabled");
    return Obx(
      () =>
          controller.teamEqota.value && hasNoTask && isEqotaEnabled
              ? EqotaWidget(
                point: controller.eqotaPoint,
                onClose: () {
                  controller.teamEqota.value = false;
                },
                ontap: () {
                  controller.teamEqota.value = false;
                  if (controller.homeController.bottomMenuIndex.value == 0) {
                    NavigationUtils.toPurchasePoints();
                  } else {
                    NavigationUtils.toTeamPurchasePoints();
                  }
                },
              )
              : SizedBox.shrink(),
    );
  }

  Widget _contentWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.only(top: 54.w, bottom: 12.w),
          decoration: BoxDecoration(
            color: ColorUtil.fromHexString(
              controller.showBoxPlayVoice.value ? "#FFFFFF" : "#F2F4F7",
            ),
            borderRadius: BorderRadius.circular(16.r),
          ),
          margin: EdgeInsets.only(bottom: 5.w),
          child: Column(
            children: [
              _buildTopVoicePlay(),
              controller.showBoxPlayVoice.value
                  ? _showBoxPlayVoice()
                  : SizedBox.shrink(),
            ],
          ),
        ),

        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: ColorUtil.fromHexString("#FFFFFF"),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.w),
                topRight: Radius.circular(20.w),
              ),
            ),
            // padding: EdgeInsets.only(bottom: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.only(top: 24.w, bottom: 12.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAIMenu().paddingSymmetric(horizontal: 24.w),
                      SizedBox(height: 12.w),
                      _folderDetailTime().paddingSymmetric(horizontal: 24.w),
                    ],
                  ),
                ),

                DividerWidget(
                  spacer: 0,
                  colors: ColorUtil.fromHexString("#EBECF0"),
                ),
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    LoggerUtils.d(
      "_buildMainContent controller.selectAIMenu.value = ${controller.selectAIMenu.value}",
    );
    return Obx(() {
      switch (controller.selectAIMenu.value) {
        case 0:
          return OutInPage();
        case 1:
          return TranscrPage();
        case 2:
          return ConcelPage();
        case 3:
        default:
          return MindPage();
      }
    });
  }

  Widget _folderDetailTime() {
    return Obx(
      () => GestureDetector(
        onTap: () {
          Get.bottomSheet(
            EditTextWidget(
              needEditText:
                  controller
                      .appController
                      .selectFileInfo
                      .value
                      .originalFilename ??
                  "",
              title: "EditFileName",
              onClick: (bool? val, String editText) {
                if (val != null && val) {
                  controller.reNameFile(editText);
                }
              },
            ),
            isScrollControlled: true,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.appController.selectFileInfo.value.originalFilename ??
                  "--",
            ).mainTitle(fontSize: 18),
            SizedBox(height: 6.w),
            Row(
              children: [
                Container(
                  margin: EdgeInsets.only(right: 4.w),
                  padding: EdgeInsets.symmetric(vertical: 2.w, horizontal: 6.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ColorUtil.fromHexString("#EAECEF"),
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  child: Text(
                    controller.appController.selectFileInfo.value.modeString!,
                  ).descText(
                    fontSize: 8,
                    color: ColorUtil.fromHexString("#7E8492"),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(3.w),
                  child: SvgPicture.asset(
                    'assets/svg/homeindex/minute.svg',
                    height: 10.w,
                    width: 9.w,
                  ),
                ),
                Text(
                  controller.appController.selectFileInfo.value.createTime ??
                      DateTimeHelper.dateTimeCoverTOString(DateTime.now()),
                  style: TextStyle(
                    color: ColorUtil.fromHexString("#B2B6BF"),
                    fontWeight: FontWeight.w400,
                    fontSize: 12.w,
                    height: 16 / 12,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(width: 10.w),
                Container(
                  padding: EdgeInsets.all(3.w),
                  child: SvgPicture.asset(
                    'assets/svg/homeindex/time.svg',
                    height: 10.w,
                    width: 9.w,
                  ),
                ),
                Text(
                  DateTimeHelper.formatDuration(
                    controller.appController.selectFileInfo.value.bizDuration ??
                        0,
                  ),
                  style: TextStyle(
                    color: ColorUtil.fromHexString("#B2B6BF"),
                    fontWeight: FontWeight.w400,
                    fontSize: 12.w,
                    height: 16 / 12,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _showBoxPlayVoice() {
    return Obx(
      () => GestureDetector(
        onVerticalDragUpdate: (details) {
          // 向上滑动：dy 是负值
          if (details.delta.dy < -10) {
            controller.showBoxPlayVoice.value = false;
          }
        },
        child: Container(
          width: Get.width,
          padding: EdgeInsets.symmetric(vertical: 12.w, horizontal: 12.w),
          decoration: BoxDecoration(
            color: ColorUtil.fromHexString("#FFFFFF"),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => Container(
                  width: Get.width,
                  margin: EdgeInsets.symmetric(vertical: 12.w),
                  height: 100.w,
                  child: AudioWaveformSlider(
                    progress: controller.sliderValue.value, // 0~1
                    onChanged: (value) {
                      controller.slidePlayProgress(value);
                    },
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateTimeHelper.formatDuration(
                      controller
                              .appController
                              .selectFileInfo
                              .value
                              .bizDuration ??
                          0,
                    ),
                  ).descText(
                    color: ColorUtil.fromHexString("#B2B6BF"),
                    fontSize: 10,
                  ),
                  Text(
                    DateTimeHelper.formatDuration(
                      controller.currentPlayTime.value,
                    ),
                  ).boldTitle(
                    color: ColorUtil.fromHexString("#B2B6BF"),
                    fontSize: 10,
                  ),
                ],
              ),

              Container(
                margin: EdgeInsets.only(left: 4.w, right: 4.w),
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: IconGesturedetector(
                        assectName:
                            controller.playerState.value == "playing"
                                ? 'assets/assets/stop1.png'
                                : 'assets/assets/play1.png',
                        ontap: () {
                          controller.voicePlay();
                        },
                        size: 40,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Spacer(),
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerLeft,
                            child: IconGesturedetector(
                              assectName: 'assets/assets/undo.png',
                              ontap: () {
                                controller.fastRewind();
                              },
                            ),
                          ),
                        ),

                        Expanded(
                          child: Container(
                            alignment: Alignment.centerRight,
                            child: IconGesturedetector(
                              assectName: 'assets/assets/redo.png',
                              ontap: () {
                                controller.fastForward();
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              controller.openSetting.value =
                                  !controller.openSetting.value;
                            },
                            child: Container(
                              alignment: Alignment.centerRight,
                              color: Colors.transparent,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    controller.speedTip.value,
                                  ).mainTitle(fontSize: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              controller.openSetting.value ? _setting() : SizedBox(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIMenu() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _aiMenuItem(
          assname: "assets/svg/device/pentool.svg",
          title: "Outln",
          index: 0,
        ),
        _aiMenuItem(
          assname: "assets/svg/device/translate.svg",
          title: "Transcr",
          index: 1,
        ),

        _aiMenuItem(
          assname: "assets/svg/device/document.svg",
          title: "Concl",
          index: 2,
        ),

        _aiMenuItem(
          assname: "assets/svg/device/gitpullrequest.svg",
          title: "MindMapped",
          index: 3,
        ),
      ],
    );
  }

  Widget _aiMenuItem({
    required String assname,
    required String title,
    required int index,
  }) {
    return Obx(
      () => GestureDetector(
        onTap: () {
          controller.selectAIMenu.value = index;
          controller.switchAIResponse();
        },
        child: Container(
          height: 32.w,
          width: controller.selectAIMenu.value == index ? 125.w : null,
          padding:
              controller.selectAIMenu.value == index
                  ? null
                  : EdgeInsets.symmetric(horizontal: 15.w),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                controller.selectAIMenu.value == index
                    ? ColorUtil.fromHexString("#7857ED", 0.2)
                    : ColorUtil.fromHexString("#F2F4F7"),
            borderRadius: BorderRadius.circular(11.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.symmetric(horizontal: 6.w),
                child: SvgPicture.asset(
                  assname,
                  color:
                      controller.selectAIMenu.value == index
                          ? ColorUtil.fromHexString("#7857ED")
                          : ColorUtil.fromHexString("#000000", 0.3),
                ),
              ),
              controller.selectAIMenu.value == index
                  ? Text(
                    title.tr,
                  ).mainTitle(color: ColorUtil.fromHexString("#7857ED"))
                  : SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopVoicePlay() {
    return Obx(
      () => Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Stack(
          alignment: Alignment.center,
          children: [
            controller.showBoxPlayVoice.value
                ? SizedBox.shrink()
                : Center(
                  child: Container(
                    height: 38.w,
                    width: 150.w,
                    decoration: BoxDecoration(
                      color: ColorUtil.fromHexString("#FFFFFF"),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 5.w),
                    child: Row(
                      children: [
                        IconGesturedetector(
                          ontap: () {
                            controller.voicePlay();
                          },
                          size: 28,
                          assectName:
                              controller.playerState.value == "playing"
                                  ? 'assets/assets/stop.png'
                                  : 'assets/assets/play.png',
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              controller.showBoxPlayVoice.value = true;
                            },
                            child: Container(
                              width: Get.width,
                              margin: EdgeInsets.only(left: 5.w),
                              height: 24.w,
                              child: AudioWaveformSlider(
                                progress: controller.sliderValue.value, // 0~1
                                // onChanged: (val) => controller.currentProgress.value = val,
                                onChanged: (value) {
                                  // if (controller.enablePlay.value ||
                                  //     controller.playerState.value == "stopped") {
                                  //   //不允许拖动音频
                                  // } else {
                                  //   controller.slidePlayProgress(value);
                                  // }
                                  controller.slidePlayProgress(value);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            SizedBox(width: 20.w),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconGesturedetector(
                  assectName: "assets/assets/back.png",
                  ontap: () {
                    controller.onClose();
                    Get.back();
                  },
                ),
                Row(
                  children: [
                    IconGesturedetector(
                      assectName: "assets/assets/share.png",
                      ontap: () {
                        Get.bottomSheet(
                          AudioSurePage(
                            isPersonal: controller.isPersonalFile.value,
                            fileId: controller.currentVoiceFile.value.fileId,
                          ),
                          isScrollControlled: true,
                        );
                      },
                    ),
                    SizedBox(width: 15.w),
                    IconGesturedetector(
                      assectName: "assets/assets/more.png",
                      ontap: () {
                        Get.bottomSheet(
                          VoiceMoreOperationsWidget(
                            isPersonal: controller.isPersonalFile.value,
                          ),
                          isScrollControlled: true,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _setting() {
    return Container(
      margin: EdgeInsets.only(top: 10.w),
      height: 43.w,
      width: Get.width,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 10.w,
            child: Container(
              width: Get.width - 75.w,
              height: 1.w,
              decoration: BoxDecoration(
                color: ColorUtil.fromHexString("#E5E6EB"),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _speed("0.5x"),
              _speed("0.75x"),
              _speed("1.0x"),
              _speed("1.25x"),
              _speed("1.5x"),
              _speed("2.0x"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _speed(String speed) {
    return Obx(
      () => GestureDetector(
        onTap: () {
          controller.speedTip.value = speed;
          switch (speed) {
            case "0.5x":
              controller.audioPlayer.setSpeed(0.5);
              break;
            case "0.75x":
              controller.audioPlayer.setSpeed(0.75);
              break;
            case "norm":
            case "1.0x":
              controller.audioPlayer.setSpeed(1);
              break;
            case "1.25x":
              controller.audioPlayer.setSpeed(1.25);
              break;
            case "1.5x":
              controller.audioPlayer.setSpeed(1.5);
              break;
            case "2.0x":
              controller.audioPlayer.setSpeed(2);
              break;
          }
        },
        child: Container(
          width: 50.w,
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              controller.speedTip.value == speed
                  ? Image.asset(
                    'assets/images_v3/speedSelect.png',
                    width: 18.w,
                    height: 18.w,
                  )
                  : Container(
                    height: 5.w,
                    width: 5.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5.w),
                      color: ColorUtil.fromHexString("#CED1D8"),
                    ),
                  ),
              SizedBox(height: 5.w),
              Text(
                speed.tr,
                style: TextStyle(
                  color: ColorUtil.fromHexString(
                    controller.speedTip.value == speed ? "#7857ED" : "#7E8492",
                  ),
                  fontWeight: FontWeight.w400,
                  fontSize: 12.w,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

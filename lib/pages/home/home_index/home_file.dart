import 'dart:io';

import 'package:dting/pages/home/home_index/select_folder.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';
import 'package:dting/pages/home/home_index/homeindex_controller_ext.dart';
import 'package:dting/pages/home/home_index/home_file_extension.dart';
import 'package:dting/pages/home/folder_manage/widget/edit_text_widget.dart';
import 'package:dting/pages/home/widget/draggable_recording_widget.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/pages/home/home_index/upload_queue_widget.dart';
import 'package:flutter/material.dart';
import 'package:dting/widgets/nodata_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'FileTransferStatusWidget.dart';
import 'homeindex_controller.dart';

class HomeFilePage extends GetView<HomeIndexController> {
  const HomeFilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            await Future.delayed(const Duration(milliseconds: 200));
            if (Platform.isAndroid) {
              await NvEasyPlugin().minimizeApp();
            }
          }
        },
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Stack(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  margin: EdgeInsets.only(top: 60.w),
                  child: Column(
                    children: [
                      // 顶部区域：设备信息或多选状态
                      _buildTopSection(),

                      // 文件传输状态
                      _buildFileTransferStatus(),

                      // 录音状态显示
                      _buildRecordingStatus(),

                      // 语音列表（现在包含上传队列）
                      _buildVoiceListSection(),
                    ],
                  ).paddingSymmetric(horizontal: 16.w),
                ),

                // 录音拖拽组件
                DraggableForRecordingWidget(
                  controller: controller.appController,
                  onTap: _handleRecordingTap,
                ),
              ],
            ),

            // 底部多选操作栏
            controller.isMoreSelect.value
                ? buildBottomMoreSelectMore(controller)
                : SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  /// 构建语音列表区域
  Widget _buildVoiceListSection() {
    return Expanded(
      child:
          controller.showVoiceList.isNotEmpty
              ? RefreshIndicator(
                backgroundColor: ColorUtil.fromHexString("#161616"),
                color: ColorUtil.fromHexString("#7857ED"),
                onRefresh: () async => controller.initVoiceList(),
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(top: 8.w, bottom: 90.w),
                  child: Column(
                    children: [
                      // 添加待上传文件列表
                      UploadQueueWidget(),
                      SizedBox(height: 8.w),
                      // 语音列表
                      ...controller.showVoiceList.map(
                        (voice) => buildVoiceContent(controller, voice),
                      ),
                      if (controller.isMoreSelect.value) SizedBox(height: 14.h),
                    ],
                  ),
                ),
              )
              : Column(
                children: [
                  // 即使没有语音列表，也显示待上传文件列表
                  UploadQueueWidget(),
                  Expanded(child: NoDataWidget()),
                ],
              ),
    );
  }

  /// 构建录音状态显示
  Widget _buildRecordingStatus() {
    return controller.appController.recordStatus.value == 1 &&
            controller.appController.connectingDevice.value.macAddress !=
                null &&
            controller.appController.connectingDevice.value.macAddress != ""
        ? GestureDetector(
          onTap: () {
            Get.bottomSheet(
              EditTextWidget(
                title: "EditFileName",
                onClick: (bool? val, String editText) async {
                  if (val != null && val) {
                    bool isLegality = await controller.checkTextLegality(
                      text: editText,
                    );
                    if (!isLegality) {
                      return;
                    }
                    controller.appController.currentRecordingFileName.value =
                        editText;

                    Get.back();
                  }
                },
                needEditText:
                    controller.appController.currentRecordingFileName.value,
              ),
              isScrollControlled: true,
            );
          },
          child: Container(
            width: Get.width,
            margin: EdgeInsets.only(bottom: 6.w, top: 12.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.w),
            decoration: BoxDecoration(
              color: ColorUtil.fromHexString("#FFFFFF"),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.appController.currentRecordingFileName.value,
                ).mainTitle(
                  overflow: TextOverflow.ellipsis,
                  maxLine: 1,
                  fontSize: 17,
                ),
                SizedBox(height: 3.w),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      controller.appController.deviceRecordStatus.value,
                    ).mainTitle(color: ColorUtil.fromHexString("#7857ED")),
                    Lottie.asset(
                      'assets/lotties/startRecord.lottie',
                      height: 15.w,
                      fit: BoxFit.fitHeight,
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        : SizedBox();
  }

  /// 处理录音按钮点击
  void _handleRecordingTap() {
    if (controller.appController.isUploadFile.value) {
      DialogHelper.showToastDialog("uploadingFiles");
    } else {
      if (controller.appController.connectingDevice.value.macAddress == null ||
          controller.appController.connectingDevice.value.macAddress == "") {
        DialogHelper.notConnectDeviceTip(
          searchDevice: () {
            if (controller.appController.scanDeviceList.isNotEmpty) {
              Get.back();
              NavigationUtils.toSearchDevice();
            } else {
              Get.back();
              controller.handleAddDevice();
            }
          },
        );
      } else {
        controller.startRecordingVoice();
      }
    }
  }

  // 在 HomeFilePage 类中添加以下方法

  /// 构建顶部区域组件
  Widget _buildTopSection() {
    if (controller.isMoreSelect.value) {
      return buildTopMoreSelect(controller);
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildTopDeviceAndUser(controller),
          SizedBox(height: 15.w),
          FolderSidebar(),
        ],
      );
    }
  }

  /// 构建文件传输状态组件
  Widget _buildFileTransferStatus() {
    return controller.appController.isUploadFile.value
        ? FileTransferStatusWidget(controller: controller.appController)
        : SizedBox(height: 1.w);
  }
}

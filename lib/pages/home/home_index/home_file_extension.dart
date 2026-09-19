import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/pages/home/home_index/homeindex_controller_ext.dart';
import 'package:dting/pages/home/folder_manage/folder_manage_controller.dart';
import 'package:dting/pages/home/folder_manage/widget/edit_text_widget.dart';
import 'package:dting/pages/home/folder_manage/widget/move_file_to_otherfolder_widget.dart';
import 'package:dting/pages/home/widget/top_device.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/datetime_helper.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/top_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';
import 'package:vibration/vibration.dart';

import 'home_file.dart';
import 'homeindex_controller.dart';

/// HomeFilePage的UI构建方法扩展类
/// 将复杂的UI构建逻辑从主页面中抽取出来，提高代码可维护性
extension HomeFilePageExtension on HomeFilePage {
  /// 构建底部多选操作栏
  Widget buildBottomMoreSelectMore(HomeIndexController controller) {
    return Obx(
      () => Container(
        height: 90.w,
        width: Get.width,
        padding: EdgeInsets.symmetric(vertical: 16.w, horizontal: 12.w),
        decoration: BoxDecoration(
          color: ColorUtil.fromHexString("#FFFFFF"),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.w),
            topRight: Radius.circular(16.w),
          ),
          boxShadow: [
            BoxShadow(
              offset: Offset(0, -2),
              blurRadius: 26,
              spreadRadius: 0,
              color: ColorUtil.fromHexString("#16005129"),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            buildMoreMenuItem(
              controller: controller,
              assectName: 'assets/assets/rename.png',
              title: "rename",
              color:
                  controller.selectVoiceFileList.length > 1
                      ? "#B2B6BF"
                      : "#161616",
              ontap: () {
                if (controller.selectVoiceFileList.isEmpty) {
                  DialogHelper.showToastDialog("selectFile");
                } else {
                  if (controller.selectVoiceFileList.length > 1) {
                    return;
                  }

                  controller.appController.selectFileInfo.value =
                      controller.selectVoiceFileList.first;
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
                          controller.reNameForVoice(editVoiceName: editText);
                        }
                      },
                    ),
                    isScrollControlled: true,
                  );
                }
              },
            ),
            buildMoreMenuItem(
              controller: controller,
              assectName: 'assets/assets/move-file.png',
              title: "move",
              ontap: () {
                if (controller.selectVoiceFileList.isEmpty) {
                  DialogHelper.showToastDialog("selectFile");
                } else {
                  Get.put(SideBarController());
                  Get.bottomSheet(
                    MoveFileToOtherfolderWidget(
                      selectRemoveVoiceList: controller.selectVoiceFileList,
                    ),
                    isScrollControlled: true,
                  );
                }
              },
            ),
            buildMoreMenuItem(
              controller: controller,
              assectName: 'assets/assets/delete-file.png',
              title: "delete",
              color: "#E32929",
              ontap: () {
                if (controller.selectVoiceFileList.isEmpty) {
                  DialogHelper.showToastDialog("selectFile");
                } else {
                  DialogHelper.showDialogByChild(
                    title: "delete",
                    cancelText: "cancel",
                    child: Text(
                      'isDeleteSeletVoice'.tr,
                      textAlign: TextAlign.center,
                    ),
                    okOntap: () {
                      controller.deleteVoice();
                      Get.back();
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建更多菜单项
  Widget buildMoreMenuItem({
    required HomeIndexController controller,
    required String assectName,
    required String title,
    required Callback ontap,
    String color = "#161616",
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: ontap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              assectName,
              height: 20.w,
              width: 20.w,
              color: ColorUtil.fromHexString(color),
            ),
            SizedBox(height: 2.w),
            Text(
              title.tr,
            ).descText(color: ColorUtil.fromHexString(color), fontSize: 12),
          ],
        ),
      ),
    );
  }

  /// 构建文件夹侧边栏
  Widget buildFolderSidbar(HomeIndexController controller) {
    return Builder(
      builder:
          (context) => GestureDetector(
            onTap: () {
              Scaffold.of(context).openDrawer();
            },
            child: Container(
              margin: EdgeInsets.only(top: 18.w),
              child: Row(
                children: [
                  Image.asset(
                    "assets/images_v3/all-file.png",
                    width: 30.w,
                    height: 30.w,
                  ),
                  SizedBox(width: 5.w),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      "${controller.appController.selectFolderFolder.value.folderName}"
                          .tr,
                    ).boldTitle(
                      fontSize: 20,
                      maxLine: 1,
                      letterSpacing: -0.4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 5.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 1.w,
                      horizontal: 8.w,
                    ),
                    decoration: BoxDecoration(
                      color: ColorUtil.fromHexString("#E7E9EC"),
                      borderRadius: BorderRadius.circular(10.w),
                    ),
                    child: Text("${controller.showVoiceList.length}").boldTitle(
                      fontSize: 12,
                      maxLine: 1,
                      color: ColorUtil.fromHexString("#7E8492"),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  /// 构建语音内容项
  Widget buildVoiceContent(
    HomeIndexController controller,
    FileInfoModel voice,
  ) {
    final slideOffset = 0.0.obs;
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx < 0) {
          slideOffset.value += details.delta.dx;
          if (slideOffset.value < -80) slideOffset.value = -80;
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dx < -10 ||
            slideOffset.value < -40) {
          Vibration.vibrate(duration: 10);
          controller.readVoice(voice);
          controller.isMoreSelect.value = true;
          if (controller.selectVoiceFileList.contains(voice)) {
            controller.selectVoiceFileList.remove(voice);
          } else {
            controller.selectVoiceFileList.add(voice);
          }
        }
        final animation = Tween<double>(
          begin: slideOffset.value,
          end: 0,
        ).animate(
          CurvedAnimation(
            parent: AnimationController(
              vsync: Navigator.of(Get.context!),
              duration: const Duration(milliseconds: 300),
            )..forward(),
            curve: Curves.easeOut,
          ),
        );

        animation.addListener(() {
          slideOffset.value = animation.value;
        });
      },
      onTap: () {
        controller.readVoice(voice);
        if (controller.isMoreSelect.value) {
          if (controller.selectVoiceFileList.contains(voice)) {
            controller.selectVoiceFileList.remove(voice);
          } else {
            controller.selectVoiceFileList.add(voice);
          }
        } else {
          controller.appController.selectFileInfo.value = voice;
          NavigationUtils.toVoiceDetails();
        }
      },
      child: Obx(() {
        return Transform.translate(
          offset: Offset(slideOffset.value, 0),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                margin: EdgeInsets.only(bottom: 12.w),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.w),
                decoration: BoxDecoration(
                  color: ColorUtil.fromHexString("#FFFFFF"),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(voice.originalFilename ?? "").mainTitle(
                      overflow: TextOverflow.ellipsis,
                      maxLine: 1,
                      fontSize: 17,
                    ),
                    SizedBox(height: 6.w),
                    buildFolderDetailTime(controller, voice),
                    SizedBox(height: 6.w),
                    buildModeWidget(controller, voice),
                  ],
                ),
              ),
              Visibility(
                visible: voice.isRead == 0,
                child: Positioned(
                  top: 10.w,
                  right: 10.w,
                  child: Container(
                    height: 8.w,
                    width: 8.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.r),
                      color: ColorUtil.fromHexString("#E80000"),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// 构建模式标签组件
  Widget buildModeWidget(HomeIndexController controller, FileInfoModel voice) {
    var folderName = "".obs;
    var isExistFolder = controller.folderList.firstWhereOrNull(
      (folder) => folder.id == voice.folderId,
    );
    if (isExistFolder != null) {
      folderName.value = isExistFolder.folderName!;
    }
    return Container(
      margin: EdgeInsets.only(top: 4.w),
      width: double.infinity,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            margin: EdgeInsets.only(right: 4.w),
            height: 18.w,
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ColorUtil.fromHexString("#F2F4F7"),
              borderRadius: BorderRadius.circular(4.w),
            ),
            child: Text(
              voice.modeString!,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ).descText(fontSize: 10, color: ColorUtil.fromHexString("#7E8492")),
          ),
          voice.transcribeTaskId != null
              ? Container(
                height: 18.w,
                margin: EdgeInsets.only(right: 8.w),
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColorUtil.fromHexString("#F2F4F7"),
                  borderRadius: BorderRadius.circular(4.w),
                ),
                child: Text(
                  "Generated".tr,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ).descText(
                  fontSize: 10,
                  color: ColorUtil.fromHexString("#7857ED"),
                ),
              )
              : SizedBox(),

          SizedBox(width: 2.w),
          voice.folderId != null && voice.folderId!.isNotEmpty
              ? Expanded(
                child: Row(
                  children: [
                    Container(
                      height: 18.w,
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ColorUtil.fromHexString("#F2F4F7"),
                        borderRadius: BorderRadius.circular(4.w),
                      ),
                      child: Text(folderName.value).descText(
                        fontSize: 10,
                        maxLine: 1,
                        overflow: TextOverflow.ellipsis,
                        color: ColorUtil.fromHexString("#7E8492"),
                      ),
                    ),
                  ],
                ),
              )
              : SizedBox.shrink(),
        ],
      ),
    );
  }

  /// 构建顶部设备和用户区域
  Widget buildTopDeviceAndUser(HomeIndexController controller) {
    return Obx(
      () => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          controller.appController.scanDeviceList.isNotEmpty
              ? buildDeviceDetail(controller)
              : buildAddDeviceButton(controller),
          buildTopMenuList(controller),
        ],
      ),
    );
  }

  /// 构建添加设备按钮
  Widget buildAddDeviceButton(HomeIndexController controller) {
    return GestureDetector(
      onTap: () async {
        controller.handleAddDevice();
      },
      child: Container(
        height: 38.w,
        padding: EdgeInsets.only(left: 5.w, right: 10.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15.w),
          color: ColorUtil.fromHexString("#FFFFFF"),
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/images_v3/add-device.png',
              height: 28.w,
              width: 28.w,
            ),
            SizedBox(width: 10.w),
            Text("AddDtingDevice".tr).boldTitle(
              color: ColorUtil.fromHexString("#161616"),
              fontSize: 12,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建设备详情
  Widget buildDeviceDetail(HomeIndexController controller) {
    var deviceName =
        controller.appController.connectingDevice.value.deviceName ??
        (controller.appController.scanDeviceList.isNotEmpty
            ? controller.appController.scanDeviceList.first.deviceName
            : "Unknown");
    return Obx(
      () => IntrinsicWidth(
        child: GestureDetector(
          onTap: () {
            TopDialog.showTopSheet(child: TopSheetByDevice());
          },
          child: Container(
            height: 38.w,
            decoration: BoxDecoration(
              color: ColorUtil.fromHexString("#FFFFFF"),
              borderRadius: BorderRadius.circular(15.r),
            ),
            padding: EdgeInsets.all(5.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Stack(
                  clipBehavior: Clip.none, // 允许溢出
                  children: [
                    // 底层：圆形背景 + 设备图
                    ClipOval(
                      child: Container(
                        width: 28.w,
                        height: 28.w,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          color: ColorUtil.fromHexString("#E1E6EA"),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 2.w,
                        ),
                        child: Image.asset(
                          'assets/images_v3/device2.png',
                          height: 23.w,
                          width: 23.w,
                        ),
                      ),
                    ),
                    // 右下角覆盖：紫色小圆图标
                    if (controller
                                .appController
                                .connectingDevice
                                .value
                                .macAddress ==
                            null ||
                        controller
                                .appController
                                .connectingDevice
                                .value
                                .macAddress ==
                            "")
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Image.asset(
                          'assets/images_v3/disConnect.png',
                          height: 16.w,
                          width: 16.w,
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 5.w),
                Flexible(
                  child: Text(
                    deviceName ?? "Unknown",
                  ).descText(fontSize: 12, overflow: TextOverflow.ellipsis),
                ),
                SizedBox(width: 5.w),
                controller.appController.connectingDevice.value.macAddress !=
                        null
                    ? Row(
                      children: [
                        Image.asset(
                          controller.appController.batteryIconUrl.value,
                          height: 20.w,
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          "${controller.appController.showBatteryString}%",
                        ).descText(),
                      ],
                    )
                    : Image.asset(
                      "assets/images_v3/battery80.png",
                      height: 20.w,
                      color: Colors.grey,
                    ),

                SizedBox(width: 5.w),
                Image.asset(
                  controller.appController.meetingStatus.value == 0
                      ? "assets/images_v3/meeting.png"
                      : "assets/images_v3/calling.png",
                  height: 20.w,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建顶部菜单列表
  Widget buildTopMenuList(HomeIndexController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            controller.importVoice();
          },
          child: SizedBox(
            width: 30.w,
            child: Image.asset(
              'assets/images_v3/import.png',
              width: 24.w,
              height: 24.w,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        GestureDetector(
          onTap: () {
            NavigationUtils.toSearch();
          },
          child: SizedBox(
            width: 30.w,
            child: Image.asset(
              'assets/images_v3/search.png',
              width: 24.w,
              height: 24.w,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建顶部多选状态
  Widget buildTopMoreSelect(HomeIndexController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "${"Selected".tr}（${controller.selectVoiceFileList.length}）",
        ).mainTitle(fontSize: 18),
        GestureDetector(
          onTap: () {
            controller.isMoreSelect.value = false;
            controller.selectVoiceFileList.value = [];
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.w),
            decoration: BoxDecoration(
              color: ColorUtil.fromHexString("#161616"),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              "Completed".tr,
            ).descText(color: ColorUtil.fromHexString("#FFFFFF")),
          ),
        ),
      ],
    );
  }

  /// 构建文件夹详情时间
  Widget buildFolderDetailTime(
    HomeIndexController controller,
    FileInfoModel voice,
  ) {
    return Obx(
      () => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(3.w),
                child: SvgPicture.asset(
                  'assets/svg/homeindex/minute.svg',
                  height: 14.w,
                  width: 14.w,
                ),
              ),
              Text(voice.recordStartTime ?? "").descText(
                color: ColorUtil.fromHexString("#B2B6BF"),
                fontSize: 12.w,
                letterSpacing: -0.4,
              ),
              SizedBox(width: 10.w),
              Container(
                padding: EdgeInsets.all(3.w),
                child: SvgPicture.asset(
                  'assets/svg/homeindex/time.svg',
                  height: 14.w,
                  width: 14.w,
                ),
              ),
              Text(
                DateTimeHelper.formatDuration(voice.bizDuration!),
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
          Visibility(
            visible: controller.isMoreSelect.value,
            child:
                controller.selectVoiceFileList.contains(voice)
                    ? Image.asset(
                      'assets/assets/check.png',
                      height: 15.w,
                      width: 15.w,
                    )
                    : Image.asset(
                      'assets/assets/radio.png',
                      height: 15.w,
                      width: 15.w,
                    ),
          ),
        ],
      ),
    );
  }
}

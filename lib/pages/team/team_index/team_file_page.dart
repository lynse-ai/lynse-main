import 'dart:io';

import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/pages/home/folder_manage/widget/edit_text_widget.dart';
import 'package:dting/pages/team/team_index/invite_member.dart';
import 'package:dting/pages/team/team_index/add_team.dart';
import 'package:dting/pages/team/team_index/draggable_add_file.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/pages/team/team_index/top_teams.dart';
import 'package:dting/pages/team/team_index/upload_queue_widget.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/datetime_helper.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/image_network.dart';
import 'package:dting/widgets/top_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:dting/utils/color_util.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';
import 'package:vibration/vibration.dart';

class TeamFilePage extends GetView<TeamFileController> {
  const TeamFilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 拦截返回
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // controller.appController.handleBackground();
          await Future.delayed(const Duration(milliseconds: 200));
          // 使用现有的NvEasyPlugin最小化应用
          //这里需要判断是否是Android
          if (Platform.isAndroid) {
            await NvEasyPlugin().minimizeApp();
          }
        }
      },
      child: Stack(
        children: [
          Obx(
            () => Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SafeArea(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    margin: EdgeInsets.only(top: 16.w),
                    child: Column(
                      children: [
                        _buildTopTeam(),
                        Expanded(
                          child:
                              controller.currentTeam.value.id.isNotEmpty &&
                                      controller.currentTeam.value.id != "-1"
                                  ? Column(
                                    children: [
                                      SizedBox(height: 20.w),
                                      _purchasePoints(),
                                      SizedBox(height: 15.w),

                                      Expanded(
                                        child: Column(
                                          children: [
                                            _teamManageOrAddMember(),
                                            SizedBox(height: 12.w),
                                            controller.isMoreSelect.value
                                                ? _buildTopMoreSelect()
                                                : SizedBox(),
                                            _buildTeamVoiceList(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                  : _notFindDate(title: "notJointTeam"),
                        ),
                      ],
                    ),
                  ),
                ),
                controller.isMoreSelect.value
                    ? _buildBottomMoreSelectMore()
                    : SizedBox.shrink(),
              ],
            ),
          ),
          DiaLogAddFileWidgetWidget(
            onClick: (val) {
              if (val != null) {
                if (val) {
                  NavigationUtils.toShareTeamFile();
                } else {
                  controller.importVoiceByPhone();
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeamVoiceList() {
    return Obx(
      () => Expanded(
        child:
            controller.voiceList.isNotEmpty
                ? RefreshIndicator(
                  backgroundColor: ColorUtil.fromHexString("#161616"),
                  color: ColorUtil.fromHexString("#7857ED"),
                  onRefresh: () async => controller.initVoiceListByTeamId(),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(top: 8.w, bottom: 20.w),
                    child: Column(
                      children: [
                        // 添加待上传文件列表
                        TeamUploadQueueWidget(),
                        SizedBox(height: 8.w),
                        // 语音列表
                        ...controller.voiceList.map(
                          (voice) => _buildVoiceContent(voice),
                        ),
                        if (controller.isMoreSelect.value)
                          SizedBox(height: 14.h),
                      ],
                    ),
                  ),
                )
                : Column(
                  children: [
                    // 即使没有语音列表，也显示待上传文件列表
                    TeamUploadQueueWidget(),
                    Expanded(
                      child: _notFindDate(
                        title: "noFile",
                        ontap: () {
                          //
                        },
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _notFindDate({
    required String title,
    Callback? ontap,
    String? ontapTitle,
  }) {
    return SizedBox(
      width: Get.width,
      height: Get.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            "assets/images_v3/analyze.png",
            height: 40.w,
            width: 40.w,
          ),
          SizedBox(height: 10.w),
          Text(title.tr).boldTitle(fontSize: 18),
          SizedBox(height: 10.w),

          if (ontapTitle != null)
            GestureDetector(
              onTap: ontap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 32.w,
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      color: ColorUtil.fromHexString("#E4E7EC"),
                    ),
                    child: Text(ontapTitle.tr).descText(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomMoreSelectMore() {
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
            _moreMenuItem(
              assectName: 'assets/assets/rename.png',
              title: "rename",
              color:
                  controller.selectVoiceFileList.length > 1
                      ? "#B2B6BF"
                      : "#161616",
              ontap: () {
                if (controller.selectVoiceFileList.isEmpty) {
                  DialogHelper.showToastDialog("selectTeam");
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

            _moreMenuItem(
              assectName: 'assets/assets/delete-file.png',
              title: "delete",
              color: "#E32929",
              ontap: () {
                if (controller.selectVoiceFileList.isEmpty) {
                  DialogHelper.showToastDialog("selectFile".tr);
                } else {
                  DialogHelper.showDialogByChild(
                    title: "delete",
                    cancelText: "cancel",
                    child: Text(
                      'isDeleteSeletVoice'.tr,
                      textAlign: TextAlign.center,
                    ),
                    okOntap: () {
                      controller.deleteTeamsVoices();
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

  Widget _moreMenuItem({
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

  Widget _buildVoiceContent(FileInfoModel voice) {
    final slideOffset = 0.0.obs; // 使用GetX管理滑动偏移量
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // 只处理向左滑动
        if (details.delta.dx < 0) {
          slideOffset.value += details.delta.dx;
          // 限制最大滑动距离为-80
          if (slideOffset.value < -80) slideOffset.value = -80;
        }
      },
      onHorizontalDragEnd: (details) {
        // 判断滑动方向
        if (controller.currentTeam.value.currentCustomerRole != 0) {
          if (details.velocity.pixelsPerSecond.dx < -10 ||
              slideOffset.value < -40) {
            // 添加震动反馈
            Vibration.vibrate(duration: 10); // 10ms短震动
            controller.isMoreSelect.value = true;
            if (controller.selectVoiceFileList.contains(voice)) {
              controller.selectVoiceFileList.remove(voice);
            } else {
              controller.selectVoiceFileList.add(voice);
            }
          }
        }
        // 添加回弹动画（无论滑动了多少都会弹回）
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
        if (controller.isMoreSelect.value) {
          if (controller.selectVoiceFileList.contains(voice)) {
            controller.selectVoiceFileList.remove(voice);
          } else {
            controller.selectVoiceFileList.add(voice);
          }
        } else {
          controller.appController.selectFileInfo.value = voice;
          NavigationUtils.toVoiceDetails(isPersonalFile: false);
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(voice.originalFilename ?? "--").mainTitle(
                      overflow: TextOverflow.ellipsis,
                      maxLine: 1,
                      fontSize: 17,
                    ),
                    SizedBox(height: 6.w),
                    _folderDetailTime(voice),
                    voice.transcribeTaskId != null
                        ? _modeWidget(voice)
                        : SizedBox(),
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

  Widget _modeWidget(FileInfoModel voice) {
    return Container(
      margin: EdgeInsets.only(top: 8.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            height: 18.w,
            margin: EdgeInsets.only(right: 8.w),
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ColorUtil.fromHexString("#F2F4F7"),
              borderRadius: BorderRadius.circular(3.w),
            ),
            child: Text(
              "Generated".tr,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ).descText(fontSize: 8, color: ColorUtil.fromHexString("#7857ED")),
          ),
        ],
      ),
    );
  }

  Widget _folderDetailTime(FileInfoModel voice) {
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
              Text(
                voice.createTime ?? "",
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

  Widget _buildTopMoreSelect() {
    return Obx(
      () => Container(
        margin: EdgeInsets.only(bottom: 12.w),
        child: Row(
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
        ),
      ),
    );
  }

  Widget _buildTopTeam() {
    bool isShowingTeamSheet = false;
    return Obx(
      () => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: IntrinsicWidth(
              child: GestureDetector(
                onTap: () async {
                  if (isShowingTeamSheet) return; // 已经弹出，不再触发
                  isShowingTeamSheet = true;

                  await controller.appController.getAllTeamList();

                  TopDialog.showTopSheet(child: TopSheetByTeamListWidgets());

                  isShowingTeamSheet = false; // 弹窗关闭后解锁
                },
                child: Container(
                  height: 40.w,
                  padding: EdgeInsets.only(right: 10.w, left: 5.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15.r),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      controller.currentTeam.value.id == "-1" ||
                              controller.currentTeam.value.id.isEmpty
                          ? Image.asset(
                            "assets/images_v3/change.png",
                            width: 28.w,
                            height: 28.w,
                          )
                          : ImageNetwork(
                            url: controller.currentTeam.value.avatarUrl,
                            size: 28.w,
                            defaultImage: 'assets/images_v3/team-avatar.png',
                          ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Text(
                          controller.currentTeam.value.id == "-1" ||
                                  controller.currentTeam.value.id.isEmpty
                              ? "changeTeam".tr
                              : controller.currentTeam.value.teamName,
                        ).descText(
                          fontSize: 12,
                          overflow: TextOverflow.ellipsis,
                          maxLine: 1,
                        ),
                      ),
                      SizedBox(width: 5.w),
                      Image.asset(
                        'assets/images_v3/team-change.png',
                        width: 18.w,
                        height: 18.w,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 20.w),
          GestureDetector(
            onTap: () {
              controller.getRandomAvatarUrl();
              controller.createTeamController.text = "";
              Get.bottomSheet(
                AddTeamWidget(),
                isDismissible: true,
                isScrollControlled: true,
              );
            },
            child: Text(
              "createTeam".tr,
            ).descText(color: ColorUtil.fromHexString("#7857ED")),
          ),
          // SizedBox(width: 5.w),
          // GestureDetector(
          //   onTap: () {
          //     NavigationUtils.toSearchTeams();
          //   },
          //   child: SizedBox(
          //     width: 30.w,
          //     child: Image.asset(
          //       'assets/images_v3/search.png',
          //       width: 22.w,
          //       height: 22.w,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _purchasePoints() {
    return Obx(
      () => Container(
        width: Get.width,
        padding: EdgeInsets.symmetric(vertical: 15.w, horizontal: 14.w),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.w),
          gradient: LinearGradient(
            colors: [
              ColorUtil.fromHexString("#DDEBFF"),
              ColorUtil.fromHexString("#ECC6FF"),
              ColorUtil.fromHexString("#8968EF"),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.40, 0.80],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text("${"teamPoint".tr}：").mainTitle(
                        color: ColorUtil.fromHexString("#7857ED"),
                        fontSize: 17,
                        maxLine: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "${controller.currentTeam.value.remainPointsAmountInt}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20.sp,
                          color: ColorUtil.fromHexString("#5D18C3"),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    NavigationUtils.toTeamPurchasePoints();
                  },
                  child: Container(
                    height: 29.w,
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ColorUtil.fromHexString("#1E2D46"),
                          ColorUtil.fromHexString("#48365B"),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ShaderMask(
                      shaderCallback:
                          (bounds) => LinearGradient(
                            colors: [
                              ColorUtil.fromHexString("#816EE4"),
                              ColorUtil.fromHexString("#FF94F4"),
                            ],
                          ).createShader(
                            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                          ),
                      blendMode: BlendMode.srcIn,
                      child: Text('payPoint'.tr).mainTitle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                NavigationUtils.toTeamPointHistory();
              },
              child: Row(
                children: [
                  Text("PointsRecord".tr).descText(
                    fontSize: 11,
                    color: ColorUtil.fromHexString("#7857ED"),
                  ),
                  Image.asset(
                    'assets/images_v3/arrow-right.png',
                    width: 13.w,
                    height: 13.w,
                    color: ColorUtil.fromHexString("#7857ED"),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.w),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${"Seatusage".tr}：${controller.currentTeam.value.members != null ? controller.currentTeam.value.members!.length : 0}/${controller.currentTeam.value.memberCapacity}",
                            ).descText(
                              fontSize: 10,
                              color: ColorUtil.fromHexString("#7857ED"),
                            ),
                          ),
                          Container(
                            height: 19.w,
                            padding: EdgeInsets.symmetric(horizontal: 5.w),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  ColorUtil.fromHexString("#DDEBFF"),
                                  ColorUtil.fromHexString("#ECC6FF"),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                stops: [0.0, 0.9],
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),

                            child: Text('timeFree'.tr).descText(
                              fontSize: 11,
                              color: ColorUtil.fromHexString("#7857ED"),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.w),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value:
                                  controller
                                      .currentTeam
                                      .value
                                      .percentMembersDouble,
                              backgroundColor: ColorUtil.fromHexString(
                                "#D9E4FF",
                              ),
                              borderRadius: BorderRadius.circular(100.r),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ColorUtil.fromHexString("#7857ED"),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Visibility(
                //   visible:
                //       controller.currentTeam.value.memberCapacity ==
                //       controller.currentTeam.value.membersInt,
                //   child: Container(
                //     height: 29.w,
                //     margin: EdgeInsets.only(left: 15.w),
                //     padding: EdgeInsets.symmetric(horizontal: 20.w),
                //     alignment: Alignment.center,
                //     decoration: BoxDecoration(
                //       gradient: LinearGradient(
                //         colors: [
                //           ColorUtil.fromHexString("#1E2D46"),
                //           ColorUtil.fromHexString("#48365B"),
                //         ],
                //         begin: Alignment.topLeft,
                //         end: Alignment.bottomRight,
                //       ),
                //       borderRadius: BorderRadius.circular(20),
                //     ),
                //     child: ShaderMask(
                //       shaderCallback:
                //           (bounds) => LinearGradient(
                //             colors: [
                //               ColorUtil.fromHexString("#816EE4"),
                //               ColorUtil.fromHexString("#FF94F4"),
                //             ],
                //           ).createShader(
                //             Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                //           ),
                //       blendMode: BlendMode.srcIn,
                //       child: Text('购买席位').mainTitle(fontSize: 15),
                //     ),
                //   ),
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamManageOrAddMember() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              NavigationUtils.toMembers();
            },
            child: Container(
              alignment: Alignment.center,
              width: Get.width,
              height: 44.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                color: ColorUtil.fromHexString("#FFFFFF"),
                border: Border.all(
                  color: ColorUtil.fromHexString("#7857ED"),
                  width: 1.w,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images_v3/team-manage.png',
                    width: 20.w,
                    height: 20.w,
                  ),
                  SizedBox(width: 5.w),
                  Text("teamManage".tr).boldTitle(
                    color: ColorUtil.fromHexString("#7857ED"),
                    fontSize: 12,
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 15.w),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (controller.currentTeam.value.currentCustomerRole != 0) {
                Get.bottomSheet(
                  isDismissible: true,
                  InviteMemberWidget(
                    onClick: (List<String> val) {
                      controller.inviteMemberJoinOurTeam(inviteePhoneList: val);
                    },
                  ),
                  isScrollControlled: true,
                );
              } else {
                DialogHelper.showToastDialog("permissionDenied");
              }
            },
            child: Container(
              alignment: Alignment.center,
              width: Get.width,
              height: 44.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                color: ColorUtil.fromHexString("#FFFFFF"),
                border: Border.all(
                  color: ColorUtil.fromHexString("#7857ED"),
                  width: 1.w,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images_v3/team-add-member.png',
                    width: 20.w,
                    height: 20.w,
                  ),
                  SizedBox(width: 5.w),
                  Text("addMember".tr).boldTitle(
                    color: ColorUtil.fromHexString("#7857ED"),
                    fontSize: 12,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

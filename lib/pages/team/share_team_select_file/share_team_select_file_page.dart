import 'package:dting/model/file_model/file_management_model/file_info.dart'; 
import 'package:dting/pages/team/share_team_select_file/share_team_select_file_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/datetime_helper.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/nodata_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:dting/utils/color_util.dart';

class ShareTeamSelectFilePage extends GetView<ShareTeamSelectFileController> {
  const ShareTeamSelectFilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // final controller = Get.put(ShareTeamSelectFileController());
    return Scaffold(
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      appBar: AppBarWidgets.getAppBar(
        title: "selectFromFile",
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      ),
      body: Container(
        color: ColorUtil.fromHexString("#F2F4F7"),
        padding: EdgeInsets.only(
          left: 24.w,
          right: 24.w,
          bottom: 6.w,
          top: 16.w,
        ),
        width: Get.width,
        height: Get.height,
        child: _searchVoiceListContent(),
      ),
      bottomNavigationBar: _bottomNavigationWidget(),
    );
  }

  Widget _bottomNavigationWidget() {
    return Container(
      height: 112.w,
      padding: EdgeInsets.symmetric(vertical: 16.w, horizontal: 24.w),
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
        children: [
          Expanded(
            child: BottomBarWidget(
              height: 48,
              fontsize: 14,
              title: "copyToTeam",
              ontap: () {
                if (controller.selectVoiceFilesList.isNotEmpty) {
                  controller.copyOrMoveFileList(
                    copyOrMove: true,
                    isPersonal: true,
                    selectTeamList: [
                      controller.teamFileController.currentTeam.value,
                    ],
                  );
                } else {
                  DialogHelper.showToastDialog("selectFile");
                }
              },
            ),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (controller.selectVoiceFilesList.isNotEmpty) {
                  if (controller.selectVoiceFilesList.length > 1) {
                    DialogHelper.showToastDialog("selectOneFile");
                  } else {
                    controller.copyOrMoveFileList(
                      copyOrMove: false,
                      isPersonal: true,
                      selectTeamList: [
                        controller.teamFileController.currentTeam.value,
                      ],
                    );
                  }
                } else {
                  DialogHelper.showToastDialog("selectFile");
                }
              },
              child: Container(
                alignment: Alignment.center,
                width: Get.width,
                height: 48.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  color: ColorUtil.fromHexString("#FFFFFF"),
                  border: Border.all(
                    color: ColorUtil.fromHexString("#7857ED"),
                    width: 1.w,
                  ),
                ),
                child: Text("moveToTeam".tr).boldTitle(
                  color: ColorUtil.fromHexString("#7857ED"),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchVoiceListContent() {
    return Obx(() {
      final list = controller.voiceFilesList;
      if (list.isEmpty) {
        return NoDataWidget(
          assectName: "assets/images_v3/analyze.png",
          tipText: "noFile".tr,
          size: 40,
        );
      }
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: list.length,
        itemBuilder: (context, index) {
          final voice = list[index];
          return _buildVoiceContent(voice);
        },
      );
    });
  }

  Widget _buildVoiceContent(FileInfoModel voice) {
    return Obx(
      () => Stack(
        alignment: Alignment.topRight,
        children: [
          GestureDetector(
            onTap: () {
              if (controller.selectVoiceFilesList.contains(voice)) {
                controller.selectVoiceFilesList.remove(voice);
              } else {
                controller.selectVoiceFilesList.add(voice);
              }
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 12.w),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.w),
              decoration: BoxDecoration(
                color: ColorUtil.fromHexString("#FFFFFF"),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Image.asset(
                    controller.selectVoiceFilesList.contains(voice)
                        ? 'assets/images_v3/select-member.png'
                        : 'assets/images_v3/un-select-member.png',
                    width: 20.w,
                    height: 20.w,
                  ),
                  SizedBox(width: 20.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                voice.originalFilename ?? "--",
                              ).mainTitle(
                                overflow: TextOverflow.ellipsis,
                                maxLine: 1,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 6.w),
                        _folderDetailTime(voice),

                        _modeWidget(voice),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Visibility(
          //   visible: voice.isRead == 0,
          //   child: Positioned(
          //     top: 10.w,
          //     right: 10.w,
          //     child: Container(
          //       height: 8.w,
          //       width: 8.w,
          //       decoration: BoxDecoration(
          //         borderRadius: BorderRadius.circular(10.r),
          //         color: ColorUtil.fromHexString("#E80000"),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _modeWidget(FileInfoModel voice) {
    return Container(
      margin: EdgeInsets.only(top: 8.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              voice.transcribeTaskId != null
                  ? Container(
                    margin: EdgeInsets.only(right: 8.w),
                    padding: EdgeInsets.symmetric(
                      vertical: 2.w,
                      horizontal: 6.w,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ColorUtil.fromHexString("#EAE1FF"),
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                    child: Text(
                      "Generated".tr,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ).descText(
                      fontSize: 8,
                      color: ColorUtil.fromHexString("#7857ED"),
                    ),
                  )
                  : SizedBox(),
              Container(
                margin: EdgeInsets.only(right: 4.w),
                padding: EdgeInsets.symmetric(vertical: 2.w, horizontal: 6.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColorUtil.fromHexString("#EAECEF"),
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: Text(
                  voice.modeString!,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ).descText(
                  fontSize: 8,
                  color: ColorUtil.fromHexString("#7E8492"),
                ),
              ),
              // SizedBox(width: 2.w),
              // ImageNetwork(url: voice.avatarUrl, size: 18),
              // SizedBox(width: 2.w),
              // Text(
              //   voice.nickname ?? "***",
              //   maxLines: 2,
              //   overflow: TextOverflow.ellipsis,
              // ).descText(
              //   color: ColorUtil.fromHexString("#1E1E1E"),
              //   fontSize: 12,
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _folderDetailTime(FileInfoModel voice) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(3.w),
              child: SvgPicture.asset(
                'assets/svg/homeindex/minute.svg',
                height: 10.w,
                width: 9.w,
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
                height: 10.w,
                width: 9.w,
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
      ],
    );
  }
}

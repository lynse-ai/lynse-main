import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/pages/home/recycle_bin/recycle_bin_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/datetime_helper.dart';

import 'package:dting/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import 'package:dting/utils/color_util.dart';

class RecycleBinPage extends GetView<RecycleBinController> {
  const RecycleBinPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      appBar: AppBarWidgets.getAppBar(
        title: "RecycleBin".tr,
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      ),
      body: SafeArea(
        bottom: false,
        child: Obx(
          () => Container(
            height: Get.height,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.w),
            color: ColorUtil.fromHexString("#F2F4F7"),
            child: SingleChildScrollView(
              child: Column(
                children:
                    controller.binVoiceFilesList
                        .map((voice) => _buildVoiceContent(voice))
                        .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceContent(FileInfoModel voice) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: ColorUtil.fromHexString("#FFFFFF"),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
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
                SizedBox(height: 6.w),
                _modeWidget(voice),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              controller.refreshVoice(voice);
            },
            child: Column(
              children: [
                Image.asset(
                  'assets/images_v3/refresh.png',
                  height: 24.w,
                  width: 24.w,
                ),
                Text("bin_refresh".tr).descText(
                  fontSize: 12,
                  color: ColorUtil.fromHexString("#7857ED"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeWidget(FileInfoModel voice) {
    return Container(
      margin: EdgeInsets.only(top: 4.w),
      width: Get.width,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          voice.transcribeTaskId != null
              ? Container(
                margin: EdgeInsets.only(right: 8.w),
                padding: EdgeInsets.symmetric(vertical: 2.w, horizontal: 6.w),
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
              borderRadius: BorderRadius.circular(4.w),
            ),
            child: Text(
              voice.modeString!,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ).descText(fontSize: 8, color: ColorUtil.fromHexString("#7E8492")),
          ),
        ],
      ),
    );
  }

  Widget _folderDetailTime(FileInfoModel voice) {
    return Row(
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
    );
  }
}

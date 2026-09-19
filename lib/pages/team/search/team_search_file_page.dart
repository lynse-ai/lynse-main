import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/pages/team/search/team_search_file_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/datetime_helper.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/image_network.dart';
import 'package:dting/widgets/nodata_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:dting/utils/color_util.dart';

class TeamSearchFilePage extends GetView<TeamSearchFileController> {
  const TeamSearchFilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      appBar: AppBarWidgets.getAppBarWithSearch(title: _searchBar()),
      body: Container(
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
    );
  }

  _searchVoiceListContent() {
    return SingleChildScrollView(
      child: Obx(
        () =>
            controller.searchVoiceFilesList.isEmpty
                ? NoDataWidget(
                  assectName: "assets/assets/search-notfind.png",
                  tipText: "notMatchData",
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children:
                      controller.searchVoiceFilesList
                          .map((voice) => _buildVoiceContent(voice))
                          .toList(),
                ),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.only(left: 16.w, top: 4.w, bottom: 4.w, right: 16.w),
      decoration: BoxDecoration(
        color: ColorUtil.fromHexString('#FFFFFF'),
        borderRadius: BorderRadius.circular(37.w),
      ),
      clipBehavior: Clip.antiAlias,
      height: 30.w,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller.searchFileController,
              cursorColor: ColorUtil.fromHexString('#333333'),
              style: TextStyle(
                color: ColorUtil.fromHexString('#333333'),
                fontSize: 14.w,
                height: 22 / 14,
              ),
              // onChanged: (value) {
              //   controller.searchVoiceList(value);
              // },
              // inputFormatters: [OnlyLetterNumberFormatter()],
              decoration: InputDecoration(
                hintText: "Search".tr,
                hintStyle: TextStyle(
                  color: ColorUtil.fromHexString('#7E8492'),
                  fontSize: 14.w,
                  height: 22 / 14,
                ),
                isDense: true,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 0,
                ),
                border: InputBorder.none,
              ),
            ),
          ),

          GestureDetector(
            onTap: () {
              controller.searchVoiceList();
            },
            child: Container(
              alignment: Alignment.centerRight,
              width: 50.w,
              height: Get.height,
              child: Image.asset(
                "assets/images_v3/search.png",
                width: 16.w,
                height: 16.w,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceContent(FileInfoModel voice) {
    return GestureDetector(
      onTap: () {
        controller.appController.selectFileInfo.value = voice;
        NavigationUtils.toVoiceDetails(isPersonalFile: false);
      },
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

                _modeWidget(voice),
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
              SizedBox(width: 2.w),
              ImageNetwork(url: voice.avatarUrl, size: 18),
              SizedBox(width: 2.w),
              Text(
                voice.nickname ?? "***",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ).descText(
                color: ColorUtil.fromHexString("#1E1E1E"),
                fontSize: 12,
              ),
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
              voice.shareTime ?? "",
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

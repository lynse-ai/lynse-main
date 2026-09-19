import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/pages/home/search/search_file_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/datetime_helper.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/nodata_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:dting/utils/color_util.dart';

class SearchPage extends GetView<SearchFileController> {
  const SearchPage({super.key});
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
        child: searchVoiceListContent(),
      ),
    );
  }

  Widget searchVoiceListContent() {
    return SingleChildScrollView(
      child: Obx(
        () =>
            controller.searchVoiceFilesList.isEmpty &&
                    controller.isSearched.value
                ? NoDataWidget(
                  assectName: "assets/assets/search-notfind.png",
                  tipText: "notMatchData",
                )
                : controller.searchVoiceFilesList.isEmpty &&
                    !controller.isSearched.value
                ? Container() // 首次进入页面，列表为空时显示空容器
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
              focusNode: controller.focusNode,
              controller: controller.searchFileController,
              cursorColor: ColorUtil.fromHexString('#333333'),
              style: TextStyle(
                color: ColorUtil.fromHexString('#333333'),
                fontSize: 14.w,
                height: 22 / 14,
              ),
              onSubmitted: (value) {
                controller.searchVoiceList();
              },
              // onChanged: (value) {
              //   controller.searchVoiceList(value);
              // },
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
              // controller.searchFileController.text = "";
              // controller.searchVoiceFilesList.value =
              //     controller.allVoiceFilesList;

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
        controller.readVoice(voice);
        controller.appController.selectFileInfo.value = voice;
        NavigationUtils.toVoiceDetails();
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
                Text(
                  voice.originalFilename ?? "",
                ).mainTitle(overflow: TextOverflow.ellipsis, maxLine: 1),

                SizedBox(height: 6.w),
                _folderDetailTime(voice),
                SizedBox(height: 6.w),
                _modeWidget(voice),
              ],
            ),
          ),
          Visibility(
            visible: voice.isRead == 0,
            child: Positioned(
              top: 5.w,
              right: 5.w,
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

  _modeWidget(FileInfoModel voice) {
    return Container(
      margin: EdgeInsets.only(top: 4.w),
      child: Row(
        children: [
          Container(
            margin: EdgeInsets.only(right: 4.w),
            height: 18.w,
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ColorUtil.fromHexString("#F2F4F7"),
              borderRadius: BorderRadius.circular(3.w),
            ),
            child: Text(
              voice.modeString!,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ).descText(fontSize: 8, color: ColorUtil.fromHexString("#7E8492")),
          ),
          voice.transcribeTaskId != null
              ? Container(
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
                ).descText(
                  fontSize: 8,
                  color: ColorUtil.fromHexString("#7857ED"),
                ),
              )
              : SizedBox(),

          SizedBox(width: 2.w),

          voice.folderName != null
              ? Expanded(child: _buildFolderDesc(voice))
              : SizedBox(),
        ],
      ),
    );
  }

  Widget _buildFolderDesc(FileInfoModel voice) {
    final folderName =
        controller.homeController.folderList
            .firstWhereOrNull((folder) => folder.id == voice.folderId)
            ?.folderName ??
        "";

    return Expanded(
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
            child: Text(folderName).descText(
              fontSize: 10,
              maxLine: 1,
              overflow: TextOverflow.ellipsis,
              color: ColorUtil.fromHexString("#7E8492"),
            ),
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
      ],
    );
  }
}

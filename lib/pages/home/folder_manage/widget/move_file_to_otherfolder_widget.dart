import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/model/file_model/folder_management_model/folder_model.dart';
import 'package:dting/pages/home/folder_manage/folder_manage_controller.dart';
import 'package:dting/pages/home/folder_manage/widget/create_folder_widget.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/title_bottom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class MoveFileToOtherfolderWidget extends GetView<SideBarController> {
  const MoveFileToOtherfolderWidget({
    super.key,
    required this.selectRemoveVoiceList,
  });
  final List<FileInfoModel> selectRemoveVoiceList;
  @override
  Widget build(BuildContext context) {
    controller.moveSelectFolder.value = FolderInfo(id: "");
    return Obx(
      () => Container(
        margin: EdgeInsets.only(top: 50.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.w),
            topRight: Radius.circular(20.w),
          ),
          color: ColorUtil.fromHexString("#F2F4F7"),
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: TitleBottomWidget(title: "moveTO"),
            ),
            controller.folderList.isEmpty
                ? _notFindFolder()
                : Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          controller.initCreatefolderAndRemoveFile();
                          Get.back();
                          Get.bottomSheet(
                            CreateFolderWidget(backMoveToFolder: true),
                            isScrollControlled: true,
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          color: ColorUtil.fromHexString("#F2F4F7"),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "folder".tr,
                                style: TextStyle(
                                  color: ColorUtil.fromHexString("#7E8492"),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12.w,
                                  height: 22 / 12,
                                ),
                              ),
                              SvgPicture.asset(
                                'assets/svg/sidebar/add.svg',
                                height: 12.w,
                                width: 12.w,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Flexible(child: _haveFolderList()),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _notFindFolder() {
    return SizedBox(
      width: Get.width,
      height: 150.w,
      child: GestureDetector(
        onTap: () {
          controller.initCreatefolderAndRemoveFile();
          Get.back();
          Get.bottomSheet(
            CreateFolderWidget(backMoveToFolder: true),
            isScrollControlled: true,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "notFindFolder".tr,
            ).descText(color: ColorUtil.fromHexString("#B2B6BF")),
            SizedBox(height: 10.w),
            Text(
              "toCreate",
            ).descText(color: ColorUtil.fromHexString("#7857ED")),
          ],
        ),
      ),
    );
  }

  Widget _haveFolderList() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12.w),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    controller.folderList
                        .map((folder) => _sideBarButton(folder))
                        .toList(),
              ),
            ),
          ),

          SizedBox(height: 20.w),

          GestureDetector(
            onTap: () async {
              Get.put(SideBarController());
              await controller.moveFileByOtherFolder(selectRemoveVoiceList);
            },
            child: Container(
              alignment: Alignment.center,
              height: 40.w,
              width: Get.width,
              decoration: BoxDecoration(
                color: ColorUtil.fromHexString("#7857ED"),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                "move".tr,
                style: TextStyle(
                  color: ColorUtil.fromHexString("#FFFFFF"),
                  fontWeight: FontWeight.w400,
                  fontSize: 16.w,
                  height: 22 / 16,
                ),
              ),
            ),
          ),
          SizedBox(height: 30.w),
        ],
      ),
    );
  }

  Widget createFolderWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.only(top: 12.w),
          child: Column(children: [_createNewFolderName()]),
        ),
        SizedBox(height: 12.w),
      ],
    );
  }

  Widget _sideBarButton(FolderInfo folder) {
    return Obx(
      () => Container(
        margin: EdgeInsets.only(bottom: 10.w),
        child: GestureDetector(
          onTap: () {
            controller.moveSelectFolder.value = folder;
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                controller.moveSelectFolder.value == folder
                    ? 'assets/svg/device/selectradio.svg'
                    : 'assets/svg/device/radio.svg',
                height: 20.w,
                width: 20.w,
              ),
              SizedBox(width: 12.w),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    'assets/svg/sidebar/folder2.svg',
                    height: 20.w,
                    width: 20.w,
                  ),
                  Container(
                    width: Get.width - 120,
                    padding: EdgeInsets.only(left: 7.w),
                    child:
                        Text(
                          folder.folderName ?? "Folder",
                          maxLines: null,
                        ).boldTitle(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createNewFolderName() {
    return Container(
      height: 40.w,
      alignment: Alignment.centerLeft,
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.only(left: 16.w, right: 16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.w),
        color: ColorUtil.fromHexString("#FFFFFF"),
      ),
      child: TextField(
        controller: controller.createFolderController,
        cursorColor: ColorUtil.fromHexString('#333333'),
        style: TextStyle(
          color: ColorUtil.fromHexString('#333333'),
          fontWeight: FontWeight.w400,
          fontSize: 12.w,
          height: 14.06 / 12,
        ),
        decoration: InputDecoration(
          hintText: "inputName".tr,
          hintStyle: TextStyle(
            color: ColorUtil.fromHexString('#7E8492'),
            fontWeight: FontWeight.w400,
            fontSize: 12.w,
            height: 14.06 / 12,
          ),
          isDense: true,
          border: InputBorder.none,
        ),
      ),
    );
  }
}

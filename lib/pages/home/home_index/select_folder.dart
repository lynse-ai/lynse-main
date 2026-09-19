import 'package:dting/model/file_model/folder_management_model/folder_model.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class FolderSidebar extends GetView<HomeIndexController> {
  FolderSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Stack(
        alignment: Alignment.centerRight,
        children: [
          SizedBox(
            width: Get.width,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _defaltFolderItem(folderName: "allFile".tr, folderId: "-1"),
                  _defaltFolderItem(folderName: "notAI".tr, folderId: "-2"),
                  _defaltFolderItem(folderName: "notRead".tr, folderId: "-3"),
                  Row(
                    children:
                        controller.folderList
                            .map((folder) => _folderItem(folder))
                            .toList(),
                  ),
                ],
              ),
            ),
          ),
          _moreFolder(),
        ],
      ),
    );
  }

  Widget _moreFolder() {
    return GestureDetector(
      onTap: () {
        NavigationUtils.toFolderManage();
      },
      child: Container(
        height: 32.w,
        padding: EdgeInsets.symmetric(horizontal: 7.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
               BoxShadow(
              offset: Offset(-12,0),
              blurRadius: 12,
              spreadRadius: 0,
              color: ColorUtil.fromHexString("#F2F4F7"),
            ),
          ]
        ),
        child: Image.asset(
          'assets/images_v3/foldermore.png',
          width: 24.w,
          height: 24.w,
        ),
      ),
    );
  }

  Widget _folderItem(FolderInfo folder) {
    return Obx(
      () => GestureDetector(
        onTap: () {
          controller.appController.selectFolderFolder.value = folder;
          controller.setShowVoiceList(folderId: folder.id);
        },
        child: Container(
          height: 32.w,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 15.w),
          margin: EdgeInsets.only(right: 15.w),
          decoration:
              controller.appController.selectFolderFolder.value.id == folder.id
                  ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ColorUtil.fromHexString("#7857ED"),
                      width: 1.w,
                    ),
                    color: ColorUtil.fromHexString("#7857ED"),
                  )
                  : BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ColorUtil.fromHexString("#7E8492"),
                      width: 1.w,
                    ),
                  ),
          child: Text(folder.folderName ?? "").descText(
            color: ColorUtil.fromHexString(
              controller.appController.selectFolderFolder.value.id == folder.id
                  ? "#FFFFFF"
                  : "#7E8492",
            ),
          ),
        ),
      ),
    );
  }

  Widget _defaltFolderItem({
    required String folderName,
    required String folderId,
  }) {
    return Obx(
      () => GestureDetector(
        onTap: () {
          controller.appController.selectFolderFolder.value = FolderInfo(
            id: folderId,
            folderName: folderName,
          );
          controller.setShowVoiceList(folderId: folderId);
        },
        child: Container(
          height: 32.w,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 15.w),
          margin: EdgeInsets.only(right: 15.w),
          decoration:
              controller.appController.selectFolderFolder.value.id == folderId
                  ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ColorUtil.fromHexString("#7857ED"),
                      width: 1.w,
                    ),
                    color: ColorUtil.fromHexString("#7857ED"),
                  )
                  : BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ColorUtil.fromHexString("#7E8492"),
                      width: 1.w,
                    ),
                  ),
          child: Text(folderName.tr).descText(
            color: ColorUtil.fromHexString(
              controller.appController.selectFolderFolder.value.id == folderId
                  ? "#FFFFFF"
                  : "#7E8492",
            ),
          ),
        ),
      ),
    );
  }
}

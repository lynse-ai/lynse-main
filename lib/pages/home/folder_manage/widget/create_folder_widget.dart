import 'package:dting/pages/home/folder_manage/folder_manage_controller.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/title_bottom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class CreateFolderWidget extends GetView<SideBarController> {
  CreateFolderWidget({super.key, this.backMoveToFolder = false});
  bool backMoveToFolder;
  @override
  Widget build(BuildContext context) {
    controller.createFolderController.text = "";
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.w),
            topRight: Radius.circular(20.w),
          ),
          color: ColorUtil.fromHexString("#F2F4F7"),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 适配内容高度
          children: [
            Container(
              padding: EdgeInsets.only(left: 20.w, right: 20.w),
              child: Column(
                children: [
                  TitleBottomWidget(title: "createFolder"),
                  _createNewFolderName(),
                ],
              ),
            ),
            SizedBox(height: 25.w),
            GestureDetector(
              onTap: () {
                controller.createFolder(backMoveToFolder: backMoveToFolder);
              },
              child: Container(
                alignment: Alignment.center,
                height: 40.w,
                width: Get.width,
                decoration: BoxDecoration(
                  color: ColorUtil.fromHexString("#7857ED"),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                margin: EdgeInsets.only(left: 20.w, right: 20.w),
                child: Text(
                  "Create".tr,
                  style: TextStyle(
                    color: ColorUtil.fromHexString("#FFFFFF"),
                    fontWeight: FontWeight.w400,
                    fontSize: 16.w,
                    height: 22 / 16,
                  ),
                ),
              ),
            ),
            SizedBox(height: 40.w),
          ],
        ),
      ),
    );
  }

  Widget _createNewFolderName() {
    return Container(
      height: 40.w,
      alignment: Alignment.center,
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

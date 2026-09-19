import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'download_file_controller.dart';

class DownloadFilePage extends GetView<DownloadFileController> {
  const DownloadFilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      appBar: AppBarWidgets.getAppBar(
        title: "download".tr,
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      ),
      body: Container(
        margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.w),
          color: Colors.white,
        ),
        child: Obx(
          () => SingleChildScrollView(
            child: Column(
              children:
                  controller.files.map((file) => fileContent(file)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget fileContent(String file) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            controller.openFile(file);
          },
          child: Container(
            width: Get.width,
            padding: EdgeInsets.symmetric(vertical: 12.w, horizontal: 12.w),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    controller.showName(file),
                    style: TextStyle(
                      color: ColorUtil.fromHexString("#1E1E1E"),
                      fontWeight: FontWeight.w500,
                      fontSize: 16.w,
                      height: 24 / 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // DividerWidget(),
      ],
    );
  }
}

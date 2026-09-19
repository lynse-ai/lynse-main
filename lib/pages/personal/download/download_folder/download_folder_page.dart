import 'package:dting/pages/personal/download/download_folder/download_folder_controller.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:dting/widgets/nodata_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class DownloadFolderPage extends GetView<DownloadFolderController> {
  const DownloadFolderPage({super.key});

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
        width: Get.width,
        margin: EdgeInsets.symmetric(horizontal: 24.w,vertical: 10.w), 
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.w),
          color: Colors.white,
        ),
        child: Obx(
          () => SingleChildScrollView(
            child:
                controller.folders.isNotEmpty
                    ? Column(
                      children:
                          controller.folders
                              .map((folder) => folderContent(folder))
                              .toList(),
                    )
                    : NoDataWidget(),
          ),
        ),
      ),
    );
  }

  Widget folderContent(String folder) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            NavigationUtils.toDownloadFile(folder);
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12.w, horizontal: 12.w),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/svg/sidebar/folder.svg',
                        width: 21.95.w,
                        height: 24.w,
                      ),
                      SizedBox(width: 15.w),

                      Expanded(
                        child: Text(
                          controller.showName(folder),
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

                Container(
                  padding: EdgeInsets.only(left: 10.w),
                  child: Image.asset(
                    'assets/images_v3/arrow-right.png',
                    width: 24.w,
                    height: 24.w,
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

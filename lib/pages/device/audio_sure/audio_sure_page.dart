import 'package:dting/pages/device/audio_sure/audio_sure_controller.dart';
import 'package:dting/pages/device/audio_sure/share_link_bottom.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/Icon_gestureDetector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class AudioSurePage extends GetView<AudioSureController> {
  AudioSurePage({super.key, this.isPersonal = true, required this.fileId});
  bool isPersonal;
  String fileId;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 15.w, horizontal: 24.w),
        decoration: BoxDecoration(
          color: ColorUtil.fromHexString("#F2F4F7"),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.w),
            topRight: Radius.circular(16.w),
          ),
          boxShadow: [
            BoxShadow(
              offset: Offset(0, -0.5),
              blurRadius: 0,
              spreadRadius: 0,
              color: ColorUtil.fromHexString("#E5E6EB"),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: [
                _title(),
                GestureDetector(
                  onTap: () {
                    Get.back();
                    Get.bottomSheet(
                      ShareLinkBottomWidget(isPersonal: isPersonal),
                      isScrollControlled: true,
                    );
                  },
                  child: Container(
                    height: 40.w,
                    padding: EdgeInsets.only(left: 11.w),
                    margin: EdgeInsets.only(top: 15.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.w),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          "assets/images_v3/share.png",
                          width: 20.w,
                          height: 20.w,
                        ),
                        SizedBox(width: 3.w),
                        Text("shareLink".tr).descText(),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 10.w, bottom: 10.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.w),
                  ),

                  child: Column(
                    children:
                        controller.shareDocumentMenu
                            .map((docMenu) => _shareDocumentItem(docMenu))
                            .toList(),
                  ),
                ),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.w),
                  ),

                  child: Column(
                    children:
                        controller.shareUploadMenu
                            .map((docMenu) => _shareUploadItem(docMenu))
                            .toList(),
                  ),
                ),
              ],
            ),

            SizedBox(height: 30.w),
          ],
        ),
      ),
    );
  }

  Widget _title() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Image.asset(
                "assets/images_v3/sure_folder.png",
                width: 24.w,
                height: 24.w,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  controller
                          .appController
                          .selectFileInfo
                          .value
                          .originalFilename ??
                      "--",
                ).boldTitle(maxLine: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        SizedBox(width: 20.w),
        IconGesturedetector(
          assectName: 'assets/assets/clear2.png',
          ontap: () {
            Get.back();
          },
        ),
      ],
    );
  }

  Widget _shareUploadItem(Map<String, Object> uploadMenu) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            controller.shareUploadMenuOnClick(
              uploadMenu["title"].toString(),
              isPersonal: isPersonal,
              fileId: fileId,
            );
          },

          child: Container(
            height: 42.w,
            width: Get.width,
            padding: EdgeInsets.only(left: 11.w),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Image.asset(
                  uploadMenu["assetname"].toString(),
                  height: 16.w,
                  width: 16.w,
                  color: ColorUtil.fromHexString("#7857ED"),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(uploadMenu["title"].toString().tr).descText(),
                ),
              ],
            ),
          ),
        ),
        Divider(color: ColorUtil.fromHexString("#F2F3F5"), height: 1.w),
      ],
    );
  }

  Widget _shareDocumentItem(Map<String, Object> docMenu) {
    return Column(
      children: [
        Divider(color: ColorUtil.fromHexString("#F2F3F5"), height: 1.w),
        GestureDetector(
          onTap: () async {
            controller.shareDocumentOnClick(
              docMenu["title"].toString(),
              isPersonal,
              fileId: fileId,
            );
          },
          child: Container(
            height: 42.w,
            width: Get.width,
            padding: EdgeInsets.only(left: 11.w),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Image.asset(
                  docMenu["assetname"].toString(),
                  height: 16.w,
                  width: 16.w,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(docMenu["title"].toString().tr).descText(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

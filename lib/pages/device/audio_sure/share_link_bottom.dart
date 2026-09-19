import 'package:dting/pages/device/audio_sure/audio_sure_controller.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/Icon_gestureDetector.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class ShareLinkBottomWidget extends GetWidget<AudioSureController> {
  ShareLinkBottomWidget({super.key, this.isPersonal = true});
  bool isPersonal;
  @override
  Widget build(BuildContext context) {
    controller.includeConcl.value = 0;
    controller.includeTrans.value = 0;
    controller.includeMindMap.value = 0;
    controller.includVoice.value = 0;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(),
                DividerWidget(spacer: 10),
                Text(
                  "shareContent".tr,
                ).descText(color: ColorUtil.fromHexString("#858C9B")),
                SizedBox(height: 10.w),

                _aiMenuSelectContent(
                  title: "shareVoice",
                  assectName: "assets/images_v3/share-voice.png",
                  ontap: () {
                    if (controller.includVoice.value == 1) {
                      controller.includVoice.value = 0;
                    } else {
                      controller.includVoice.value = 1;
                    }
                  },
                ),
                SizedBox(height: 15.w),

                _aiMenuSelectContent(
                  title: "Concl",
                  assectName: "assets/images_v3/share-outline.png",
                  ontap: () {
                    if (controller.includeConcl.value == 1) {
                      controller.includeConcl.value = 0;
                    } else {
                      controller.includeConcl.value = 1;
                    }
                  },
                ),
                SizedBox(height: 15.w),

                _aiMenuSelectContent(
                  title: "Transcr",
                  assectName: "assets/images_v3/share-trans.png",
                  ontap: () {
                    if (controller.includeTrans.value == 1) {
                      controller.includeTrans.value = 0;
                    } else {
                      controller.includeTrans.value = 1;
                    }
                  },
                ),
                SizedBox(height: 15.w),

                _aiMenuSelectContent(
                  title: "MindMapped",
                  assectName: "assets/images_v3/share-map.png",
                  ontap: () {
                    if (controller.includeMindMap.value == 1) {
                      controller.includeMindMap.value = 0;
                    } else {
                      controller.includeMindMap.value = 1;
                    }
                  },
                ),
                SizedBox(height: 5.w),
                Text(
                  "linkTip".tr,
                ).descText(color: ColorUtil.fromHexString("#858C9B")),
                SizedBox(height: 15.w),
                _share(),
                SizedBox(height: 15.w),
                _copyLink(),
              ],
            ),

            SizedBox(height: 30.w),
          ],
        ),
      ),
    );
  }

  Widget _share() {
    return GestureDetector(
      onTap: () {
        controller.shareLinkToOther(isPersonal);
      },
      child: Container(
        height: 48.w,
        width: Get.width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: ColorUtil.fromHexString("#7857ED"),
        ),
        child: Text(
          'share'.tr,
        ).boldTitle(fontSize: 16, color: ColorUtil.fromHexString("#FFFFFF")),
      ),
    );
  }

  Widget _copyLink() {
    return GestureDetector(
      onTap: () {
        controller.copyLink(isPersonal);
      },
      child: Container(
        height: 48.w,
        width: Get.width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: ColorUtil.fromHexString("#E7E9EC"),
        ),
        child: Text('copyLink'.tr).boldTitle(fontSize: 16),
      ),
    );
  }

  Widget _aiMenuSelectContent({
    required String title,
    required VoidCallback ontap,
    required String assectName,
  }) {
    var tempSelect = false.obs;
    return Obx(
      () => GestureDetector(
        onTap: () {
          tempSelect.value = !tempSelect.value;
          ontap();
        },
        child: Container(
          height: 46.w,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(assectName, width: 24.w, height: 24.w),
                  Text(title.tr).descText(),
                ],
              ),
              Image.asset(
                tempSelect.value
                    ? 'assets/images_v3/select-member.png'
                    : 'assets/images_v3/un-select-member.png',
                width: 20.w,
                height: 20.w,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "shareLink".tr,
        ).boldTitle(maxLine: 2, overflow: TextOverflow.ellipsis),
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
}

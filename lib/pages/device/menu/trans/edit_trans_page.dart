import 'package:dting/model/file_model/file_processing_model/trans_model.dart';
import 'package:dting/pages/device/menu/trans/trans_controller.dart';
import 'package:dting/pages/home/folder_manage/widget/edit_text_widget.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class EditTransPage extends GetView<TransController> {
  const EditTransPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder(
      id: 'updateTransList',
      init: controller,
      builder: (c) {
        return Obx(
          () => SafeArea(
            top: false,
            bottom: false,
            child: Container(
              height: Get.height,
              width: Get.width,
              color: ColorUtil.fromHexString("#F2F4F7"),
              padding: EdgeInsets.symmetric(vertical: 54.w),
              child: Column(
                children: [
                  SizedBox(
                    height: 32.w,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () {
                            controller.editTransList.value = [];
                            controller.detailController.getTransData();
                            Get.back();
                          },
                          child: Container(
                            height: Get.height,
                            alignment: Alignment.center,
                            padding: EdgeInsets.only(left: 24.w, right: 24),
                            child: Text("cancel".tr).descText(fontSize: 15),
                          ),
                        ),

                        GestureDetector(
                          onTap: () {
                            controller.editTransSpeakList();
                          },
                          child: Container(
                            height: Get.height,
                            margin: EdgeInsets.only(right: 24.w),
                            alignment: Alignment.center,
                            padding: EdgeInsets.symmetric(horizontal: 19.w),
                            decoration: BoxDecoration(
                              color:
                                  controller.editTransList.isNotEmpty
                                      ? ColorUtil.fromHexString("#7857ED")
                                      : ColorUtil.fromHexString("#7E8492"),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text("save".tr).descText(
                              fontSize: 15,
                              color: ColorUtil.fromHexString("#FFFFFF"),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.w),

                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          children:
                              controller.detailController.transcrSpeakList
                                  .map(
                                    (speakDetail) =>
                                        _speakDetailBox(speakDetail),
                                  )
                                  .toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _speakDetailBox(TransModel speakDetail) {
    TextEditingController editSpeakerName = TextEditingController(
      text: speakDetail.text,
    );
    var speakerNameString = speakDetail.speakerName.obs;
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Get.bottomSheet(
                EditTextWidget(
                  onClick: (bool? val, String editText) {
                    if (val != null && val) {
                      controller.editAllSpeackName(speakDetail, editText);
                    } else {
                      controller.editItemSpeackName(
                        speakDetail,
                        editText,
                        speakerNameString,
                      );
                    }
                    Get.back();
                  },
                  isEditSpeackName: true,
                  needEditText: speakerNameString.value ?? "**",
                  title: "发言人重命名",
                ),
                isScrollControlled: true,
              );
            },
            child: Row(
              children: [
                Container(
                  height: 6.w,
                  width: 6.w,
                  margin: EdgeInsets.only(right: 6.w),
                  decoration: BoxDecoration(
                    color: ColorUtil.fromHexString(
                      speakDetail.speakerId == "1"
                          ? "#F11212"
                          : speakDetail.speakerId == "2"
                          ? "#FFB637"
                          : speakDetail.speakerId == "3"
                          ? "#36D20B"
                          : speakDetail.speakerId == "4"
                          ? "#0ECDDB"
                          : speakDetail.speakerId == "5"
                          ? "#5888FF"
                          : speakDetail.speakerId == "6"
                          ? "#7C48FF"
                          : "#FF4671",
                    ),
                    borderRadius: BorderRadius.circular(6.w),
                  ),
                ),

                Flexible(
                  child: Text(
                    speakerNameString.value ??
                        "${"Speaker".tr} ${speakDetail.speakerId ?? ""}",
                  ).boldTitle(
                    color: ColorUtil.fromHexString(
                      speakDetail.speakerId == "1"
                          ? "#F11212"
                          : speakDetail.speakerId == "2"
                          ? "#FFB637"
                          : speakDetail.speakerId == "3"
                          ? "#36D20B"
                          : speakDetail.speakerId == "4"
                          ? "#0ECDDB"
                          : speakDetail.speakerId == "5"
                          ? "#5888FF"
                          : speakDetail.speakerId == "6"
                          ? "#7C48FF"
                          : "#FF4671",
                    ),
                    fontSize: 12,
                    maxLine: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(speakDetail.endTimeStr ?? "").boldTitle(
                  color: ColorUtil.fromHexString("#B2B6BF"),
                  fontSize: 12,
                ),
              ],
            ),
          ),
          SizedBox(height: 8.w),
          Row(
            children: [
              SizedBox(width: 12.w),
              Flexible(
                child: TextField(
                  controller: editSpeakerName,
                  // inputFormatters: [OnlyLetterNumberFormatter()],
                  cursorColor: ColorUtil.fromHexString('#1E1E1E'),
                  style: TextStyle(
                    color: ColorUtil.fromHexString('#1E1E1E'),
                    fontSize: 14.w,
                    height: 20 / 16,
                  ),
                  maxLines: null,
                  onChanged: (value) {
                    controller.editTransText(speakDetail, value);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 0,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.w),
        ],
      ),
    );
  }
}

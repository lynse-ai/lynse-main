import 'package:dting/model/file_model/file_processing_model/trans_model.dart';
import 'package:dting/pages/device/menu/trans/edit_trans_page.dart';
import 'package:dting/pages/device/menu/trans/trans_controller.dart';
import 'package:dting/pages/device/prompt/prompt_list_controller.dart';
import 'package:dting/pages/device/prompt/prompt_list_page.dart';
import 'package:dting/pages/device/widget/animation_get_data.dart';
import 'package:dting/pages/device/widget/not_find_data.dart';
import 'package:dting/router/modules/translate_router.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/logger_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class TranscrPage extends GetView<TransController> {
  const TranscrPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 提取状态变量（提高可读性）
      final isLoading = controller.detailController.transLoading.value;
      LoggerUtils.d("isLoading: $isLoading");
      // 使用清晰的逻辑判断替代嵌套三元表达式
      if (isLoading) {
        return AnimationGetData(
          title:
              controller.appController.selectFileInfo.value.transcribeTaskId !=
                      null
                  ? "getTrans"
                  : 'GeneratingTrans',
          info: "notWaitTrans",
        );
      }

      return SafeArea(
        child: Column(
          children: [
            Expanded(child: buildNormalContent()),
            controller.isNotEmpty
                ? Text("AI-tips".tr).descText(
                  color: ColorUtil.fromHexString("#858C9B"),
                  fontSize: 12,
                )
                : SizedBox.shrink(),
            SizedBox(height: 15.w),
          ],
        ),
      );
    });
  }

  // 主内容
  Widget buildNormalContent() {
    var lastOffset = 0.0.obs;
    return Container(
      width: Get.width,
      height: Get.height,
      alignment: Alignment.topCenter,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 15.w),
      child:
          controller.appController.selectFileInfo.value.transcribeTaskId != null
              ? controller.detailController.transcrSpeakList.isNotEmpty
                  ? NotificationListener<ScrollNotification>(
                    onNotification: (ScrollNotification notification) {
                      final currentOffset = notification.metrics.pixels;

                      if (notification is ScrollUpdateNotification) {
                        if (currentOffset > lastOffset.value) {
                          controller.detailController.showBoxPlayVoice.value =
                              false;
                        } else if (currentOffset < lastOffset.value) {
                          print("下");
                        }
                        lastOffset.value = currentOffset;
                      }
                      if (currentOffset == 0.0) {
                        controller.detailController.showBoxPlayVoice.value =
                            true;
                      }

                      return true;
                    },
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children:
                            controller.detailController.transcrSpeakList
                                .map(
                                  (speakDetail) => _speakDetailBox(speakDetail),
                                )
                                .toList(),
                      ),
                    ),
                  )
                  : NotFindData(
                    title: "NoContent",
                    info: "checkVoice".trParams({
                      'aiMenu': "Transcr".tr, // 这里是动态数据
                    }),
                    assname: "assets/images_v3/analyze2.png",
                    isShowGetData: false,
                  )
              : NotFindData(
                title: "Transcr",
                isExamples:
                    controller.appController.selectFileInfo.value.isExamples,
                ontap: () async {
                  Get.put(PromptListController());
                  final String? templateId = await Get.to<String>(
                    () => PromptListPage(),
                    arguments: {"isFirstGenerator": true},
                  );

                  if (templateId != null) {
                    controller.detailController.getTransResponse(templateId);
                  }
                },
              ),
    );
  }

  Widget _speakDetailBox(TransModel speakDetail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
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
                speakDetail.speakerName ??
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
        SizedBox(height: 8.w),
        GestureDetector(
          onTap: () {
            Get.bottomSheet(EditTransPage(), isScrollControlled: true);
          },
          child: Row(
            children: [
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  speakDetail.text ?? "",
                  textAlign: TextAlign.left,
                ).descText(color: ColorUtil.fromHexString("#1E1E1E")),
              ),
            ],
          ),
        ),
        SizedBox(height: 20.w),
      ],
    );
  }
}

import 'package:dting/pages/device/menu/concel/concel_controller.dart';
import 'package:dting/pages/device/prompt/prompt_list_controller.dart';
import 'package:dting/pages/device/widget/ai_generator_btn_widget.dart';
import 'package:dting/pages/device/widget/animation_get_data.dart';
import 'package:dting/pages/device/widget/not_find_data.dart';
import 'package:dting/pages/device/prompt/prompt_list_page.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/logger_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class ConcelPage extends GetView<ConcelController> {
  const ConcelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 提取关键状态变量
      final isLoading = controller.detailController.concelLoading.value;

      LoggerUtils.d("isLoading: $isLoading");
      // 使用清晰的逻辑判断替代嵌套三元表达式
      if (isLoading) {
        return AnimationGetData(
          title:
              controller.appController.selectFileInfo.value.transcribeTaskId !=
                      null
                  ? "getConcl"
                  : 'GeneratingConcl',
          info: "waitTip".trParams({
            'aiMenuItemName': "Concl".tr, // 这里是动态数据
          }),
        );
      }

      return SafeArea(
        child: Column(
          children: [
            Expanded(child: buildContainer()),

            controller.isNotEmpty
                ? AiGeneratorBtnWidget(
                  text: "translatePromptModel".tr,
                  showIcon: false,
                )
                : SizedBox.shrink(),
          ],
        ),
      );
    });
  }

  Container buildContainer() {
    return Container(
      width: Get.width,
      alignment: Alignment.topCenter,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 2.w),
      child: SingleChildScrollView(child: _buildContentWidget()),
    );
  }

  /// 根据不同状态构建内容组件，替代复杂的嵌套三元表达式
  Widget _buildContentWidget() {
    // 检查是否有转写任务ID
    final hasTranscribeTaskId =
        controller.appController.selectFileInfo.value.transcribeTaskId != null;

    if (!hasTranscribeTaskId) {
      // 没有转写任务ID，显示结论相关的提示信息
      return NotFindData(
        title: "Concl",
        isExamples: controller.appController.selectFileInfo.value.isExamples,
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
      );
    }

    // 有转写任务ID，检查是否有结论文本
    final conclusionText =
        controller.detailController.conclData.value.conclusionText;
    if (conclusionText != null && conclusionText.isNotEmpty) {
      // 有有效的结论文本，显示Markdown内容
      return Column(
        children: [
          MarkdownBody(
            data: conclusionText,
            styleSheet: MarkdownStyleSheet(
              h1: TextStyle(
                fontSize: 16.8,
                fontWeight: FontWeight.bold,
                color: ColorUtil.fromHexString('#000000'),
              ),
              h2: TextStyle(
                fontSize: 16.8,
                fontWeight: FontWeight.bold,
                color: ColorUtil.fromHexString('#000000'),
              ),
              p: TextStyle(
                fontSize: 14.w,
                color: ColorUtil.fromHexString("#1E1E1E"),
                height: 21 / 14,
              ),
            ),
          ),
          SizedBox(height: 50.w),
          Text(
            "AI-tips".tr,
          ).descText(color: ColorUtil.fromHexString("#858C9B"), fontSize: 12),
        ],
      );
    } else {
      // 没有结论文本，显示无内容提示
      return NotFindData(
        title: "NoContent",
        info: "checkVoice".trParams({
          'aiMenu': "Concl".tr, // 这里是动态数据
        }),
        assname: "assets/images_v3/analyze2.png",
        isShowGetData: false,
      );
    }
  }
}

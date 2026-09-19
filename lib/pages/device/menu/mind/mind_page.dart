import 'package:dting/pages/device/menu/mind/mind_controller.dart';
import 'package:dting/pages/device/prompt/prompt_list_controller.dart';
import 'package:dting/pages/device/prompt/prompt_list_page.dart';
import 'package:dting/pages/device/widget/ai_generator_btn_widget.dart';
import 'package:dting/pages/device/widget/animation_get_data.dart';
import 'package:dting/pages/device/widget/not_find_data.dart';
import 'package:dting/router/modules/translate_router.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/logger_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MindPage extends GetView<MindController> {
  const MindPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 提取关键状态变量
      final isLoading = controller.detailController.mindmapLoading.value;

      LoggerUtils.d("isLoading: $isLoading");
      // 使用清晰的逻辑判断替代嵌套三元表达式
      if (isLoading) {
        return AnimationGetData(
          title:
              controller.appController.selectFileInfo.value.transcribeTaskId !=
                      null
                  ? "getMinMap"
                  : 'GeneratingMinMap',
          info: "waitTip".trParams({
            'aiMenuItemName': "MindMapped".tr, // 这里是动态数据
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

  Widget buildContainer() {
    return Container(
      width: Get.width,
      alignment: Alignment.topCenter,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 15.w),
      child:
          controller.appController.selectFileInfo.value.transcribeTaskId != null
              ? controller.detailController.conclData.value.conclusionText !=
                          null &&
                      controller
                              .detailController
                              .conclData
                              .value
                              .conclusionText !=
                          "" &&
                      controller.detailController.haveMindMapData.value
                  ? Column(
                    children: [
                      Expanded(
                        child: MindMapZoomableWidget(
                          webViewController:
                              controller.detailController.webViewController,
                        ),
                      ),
                      SizedBox(height: 50.w),
                      Text("AI-tips".tr).descText(
                        color: ColorUtil.fromHexString("#858C9B"),
                        fontSize: 12,
                      ),
                    ],
                  )
                  : NotFindData(
                    title: "NoContent",
                    info: "checkVoice".trParams({
                      'aiMenu': "MindMapped".tr, // 这里是动态数据
                    }),
                    assname: "assets/images_v3/analyze2.png",
                    isShowGetData: false,
                  )
              : NotFindData(
                title: "MindMapped",
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
}

/// 可缩放的思维导图组件
class MindMapZoomableWidget extends StatefulWidget {
  final WebViewController webViewController;

  const MindMapZoomableWidget({super.key, required this.webViewController});

  @override
  State<MindMapZoomableWidget> createState() => _MindMapZoomableWidgetState();
}

class _MindMapZoomableWidgetState extends State<MindMapZoomableWidget> {
  @override
  void initState() {
    super.initState();
    // 禁用WebView内部的缩放，确保缩放由Flutter控制
    widget.webViewController.enableZoom(false);
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      constrained: true,
      child: WebViewWidget(controller: widget.webViewController),
    );
  }
}

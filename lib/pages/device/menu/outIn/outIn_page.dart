import 'package:dting/pages/device/menu/outIn/outIn_controller.dart';
import 'package:dting/pages/device/prompt/prompt_list_controller.dart';
import 'package:dting/pages/device/prompt/prompt_list_page.dart';
import 'package:dting/pages/device/widget/animation_get_data.dart';
import 'package:dting/pages/device/widget/not_find_data.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/logger_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class OutInPage extends GetView<OutinController> {
  const OutInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 提取关键状态变量
      final isLoading = controller.detailController.outlnLoading.value;

      LoggerUtils.d("isLoading: $isLoading");

      // 使用清晰的逻辑判断替代嵌套三元表达式
      if (isLoading) {
        return AnimationGetData(
          title:
              controller.appController.selectFileInfo.value.transcribeTaskId !=
                      null
                  ? "getOutln"
                  : 'Generatingoutln',
          info: "waitTip".trParams({
            'aiMenuItemName': "Outln".tr, // 这里是动态数据
          }),
        );
      }
      return SafeArea(
        child: Column(
          children: [
            Expanded(child: buildContainer()),
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

  Container buildContainer() {
    return Container(
      width: Get.width,
      alignment: Alignment.topCenter,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 15.w),
      child: SingleChildScrollView(
        child:
            controller.appController.selectFileInfo.value.transcribeTaskId !=
                    null
                ? controller.detailController.outlnData.value.outlineText !=
                            null &&
                        controller
                                .detailController
                                .outlnData
                                .value
                                .outlineText !=
                            ""
                    ? Text(
                      controller.detailController.outlnData.value.outlineText ??
                          "",
                      style: TextStyle(
                        color: ColorUtil.fromHexString("#1E1E1E"),
                        fontWeight: FontWeight.w400,
                        fontSize: 14.w,
                        height: 21 / 14,
                      ),
                    )
                    : NotFindData(
                      title: "NoContent",
                      info: "checkVoice".trParams({
                        'aiMenu': "Outln".tr, // 这里是动态数据
                      }),
                      assname: "assets/images_v3/analyze2.png",
                      isShowGetData: false,
                    )
                : NotFindData(
                  title: "Outln",
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
      ),
    );
  }
}

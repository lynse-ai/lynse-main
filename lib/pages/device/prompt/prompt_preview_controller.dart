import 'package:dting/model/translate/prompt_template_model.dart';
import 'package:dting/pages/device/prompt/prompt_list_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PromptPreviewController extends GetxController {
  final PromptListController promptListController =
      Get.find<PromptListController>();

  // 分类下的模版集合
  List<PromptTemplateModel> get templateList =>
      promptListController.templateList;
  // 当前选中的第几个模版
  // int get selectTemplateIndex => promptListController.selectTemplateIndex;

  // 控制PageView的控制器 - 设置viewportFraction小于1，使左右两侧能显示相邻卡片的边缘
  final PageController pageController = PageController(
    viewportFraction: 0.92,
    initialPage: 0,
  );

  // 当前选中的页面索引
  Rx<int> currentPageIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null && Get.arguments['templateIndex'] != null) {
      currentPageIndex.value = Get.arguments['templateIndex'];
    }
  }

  // 页面变化时的处理
  void onPageChanged(int index) {
    currentPageIndex.value = index;
    promptListController.selectTemplateId.value = templateList[index].id!;
  }

  // 应用选中的模板
  void applyTemplate() {
    Get.back();
    promptListController.applySelectedTemplate();
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}

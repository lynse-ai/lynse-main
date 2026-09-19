import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/model/translate/prompt_template_model.dart';
import 'package:dting/pages/device/voice_details/voicedetails_controller.dart';
import 'package:dting/service/translate_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class PromptListController extends GetxController {
  bool isFirstGenerator = false;
  final DtingStore appController = Get.find<DtingStore>();
  FileInfoModel get fileInfo => appController.selectFileInfo.value;
  final VoiceDetailsController voiceDetailsController =
      Get.find<VoiceDetailsController>();

  var promptGroupList = [];

  RxString selectCategory = ''.obs;
  RxString selectTemplateId = ''.obs;

  /// 当前选中的文件 id
  String get selectFileId => fileInfo.id ?? '';

  /// 当前选中的菜单
  ProcessType get selectProgressType => ProcessType.values.firstWhere(
    (e) => e.name == selectCategory.value,
    orElse: () => ProcessType.CONCLUSION,
  );

  /// 分类列表
  List<String> get categoryList =>
      promptGroupList.map((e) => e['category'] as String).toList();

  // 模板列表
  List<PromptTemplateModel> get templateList {
    if (promptGroupList.isEmpty) {
      return [];
    }

    final list = promptGroupList.where(
      (e) => (e['category'] as String) == selectCategory.value,
    );
    if (list.isEmpty) {
      return [];
    }

    final templates = list.first['templates'] as List? ?? [];
    return templates.map((item) {
      final mapItem = item as Map<String, dynamic>;
      return PromptTemplateModel.fromJson(mapItem);
    }).toList();
  }

  // 当前选中分类下第几个模板
  int get selectTemplateIndex =>
      templateList.indexWhere((e) => e.id == selectTemplateId.value);

  @override
  void onReady() {
    super.onReady();
    isFirstGenerator = Get.arguments?['isFirstGenerator'] ?? false;
  }

  @override
  void onInit() {
    super.onInit();
    loadPromptList();
    isFirstGenerator = Get.arguments?['isFirstGenerator'] ?? false;
  }

  Future<void> loadPromptList() async {
    try {
      promptGroupList = await TranslateService.getPromptTemplateCategoryList();

      if (promptGroupList.isNotEmpty && selectCategory.isEmpty) {
        // 数据加载成功后，自动选择第一个分类和第一个模板
        selectCategory.value = promptGroupList.first['category'] as String;

        // 延迟一下，确保getter templateList已经更新
        Future.microtask(() {
          if (templateList.isNotEmpty && templateList.first.id != null) {
            selectTemplateId.value = templateList.first.id!;
          }
        });
      }
    } catch (e) {
      DialogHelper.showToastDialog(e.toString());
    }
  }

  /// 应用选中的模板
  void applySelectedTemplate() async {
    if (selectTemplateId.isEmpty) {
      DialogHelper.showToastDialog('请先选择一个模板');
      return;
    }

    if (isFirstGenerator) {
      isFirstGenerator = false;
      Get.back(result: selectTemplateId.value);
      return;
    }

    EasyLoading.show();
    try {
      final taskId = await TranslateService.reprocessByAIPrompt(
        aiTaskType: selectProgressType,
        fileId: selectFileId,
        templateId: selectTemplateId.value,
      );

      if (taskId != null) {
        DialogHelper.showToastDialog('应用成功');
        voiceDetailsController.concelLoading.value = true;
        voiceDetailsController.outlnLoading.value = true;
        voiceDetailsController.mindmapLoading.value = true;
        voiceDetailsController.loopRefreshStatus(
          taskId: taskId,
          aiTaskType: selectProgressType.name,
        );
      }

      // 将选中的模板ID传回上一个页面
      Get.back();
    } catch (e) {
      DialogHelper.showToastDialog(e.toString());
      return;
    } finally {
      EasyLoading.dismiss();
    }
  }
}

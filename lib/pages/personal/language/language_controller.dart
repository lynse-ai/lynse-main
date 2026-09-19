import 'dart:ui';

// 显式使用TranscriptionLanguageModel类型以避免未使用导入警告
import 'package:dting/pages/device/widget/language_list_widget.dart';
import 'package:dting/service/translate_service.dart';
import 'package:dting/utils/local_database.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class LanguageController extends GetxController {
  /// 转录语言
  RxString transLanguage = ''.obs;

  ///
  RxList<LanguageModel> transLanguageList = RxList<LanguageModel>();

  /// 当前转录语言的名称
  String get transLangLabel =>
      transLanguageList.isEmpty
          ? 'Chinese'.tr
          : transLanguageList
              .firstWhere((element) => element.name == transLanguage.value)
              .label
              .tr;

  var changeLanguage = "".obs; // 切换应用语言

  /// 应用语言列表
  List<LanguageModel> applyLanguageList = [
    LanguageModel(name: "Chinese", code: "zh", label: "Chinese"),
    LanguageModel(name: "English", code: "en", label: "English"),
  ];

  /// 语言国际化的映射
  Map<String, Locale> languageMap = {
    "Chinese": const Locale("zh", "CN"),
    "English": const Locale("en", "US"),
  };

  /// 当前应用语言的名称
  String get applyLangLabel =>
      applyLanguageList
          .firstWhere((element) => element.name == changeLanguage.value)
          .label
          .tr;

  @override
  void onInit() {
    super.onInit();
    loadLocalLanguage();
    loadTranscriptionLanguageList();
  }

  @override
  void onClose() {
    super.onClose();
    changeLanguage.value = "";
    transLanguage.value = "";
  }

  /// 加载转录语言列表
  Future<List<LanguageModel>> loadTranscriptionLanguageList() async {
    try {
      EasyLoading.show();
      transLanguageList.value = [];

      final list = await TranslateService.getTranscriptionLanguageList();
      if (list.isNotEmpty) {
        transLanguageList.addAll(
          list.map(
            (element) => LanguageModel(
              name: element.remark ?? '',
              code: element.id ?? '',
              label: element.dictValue ?? '',
            ),
          ),
        );
      }
      return transLanguageList;
    } catch (e) {
      print('loadTranscriptionLanguageList $e');
      return [];
    } finally {
      EasyLoading.dismiss();
    }
  }

  /// 显示应用语言的弹窗
  void showLanguageBottomSheet(String type) async {
    try {
      if (type == 'applyLanguage') {
        final language = await Get.bottomSheet(
          LanguageListWidget(
            settingMode: SettingMode.global,
            title: "language".tr,
            currentLanguageName: changeLanguage.value,
            languageList: applyLanguageList,
          ),
          isScrollControlled: true,
        );
        if (language != null) {
          changeLanguage.value = language.name;
          cacheLanguage(language.name);
        }
      } else {
        final language = await Get.bottomSheet(
          LanguageListWidget(
            settingMode: SettingMode.global,
            title: "transLanguage".tr,
            currentLanguageName: transLanguage.value,
            languageList: transLanguageList,
            maxHeight: 500.w,
          ),
          isScrollControlled: true,
        );
        if (language != null) {
          transLanguage.value = language.name;
          // cacheLanguage(language.name);
        }
      }
    } catch (e) {
      print('showLanguageBottomSheet $e');
    }
  }

  //获取原始的语言
  void loadLocalLanguage() {
    // 获取当前应用语言
    var locale = Get.locale;
    if (locale != null) {
      if (locale.languageCode == "zh") {
        changeLanguage.value = "Chinese";
      } else {
        changeLanguage.value = "English";
      }
    }

    /// 获取缓存的转录语言
    String? transLang = LocalDataBase().basicBox!.get("transLanguage");
    if (transLang != null) {
      transLanguage.value = transLang;
    }
  }

  /// 缓存当前选中的语言
  void cacheLanguage(String languageName) {
    final langLocale = languageMap[languageName];
    if (langLocale != null) {
      Get.updateLocale(langLocale);

      var locale = Get.locale; //获取当前设备的语言
      if (locale != null && locale.countryCode != null) {
        var language = "${locale.languageCode}-${locale.countryCode!}";
        LocalDataBase().basicBox!.put("language", language);
      }
    }
  }
}

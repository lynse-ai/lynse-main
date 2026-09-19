import 'package:dting/model/baseapi/response_api_model.dart';
import 'package:dting/model/payment/translate_history_model.dart';
import 'package:dting/model/personal_model/transcription_language_model.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:get/get.dart';
import 'package:dting/http/http_helper.dart';

enum ProcessType { TRANSCRIPTION, CONCLUSION, OUTLINE }

class TranslateService {
  /// 发起翻译
  static Future<bool> translateFile({
    required String fileId,
    required String sourceLanguage,
    required String targetLanguage,
    String? taskId,
    String? text,
    ProcessType? type,
  }) async {
    try {
      final ResponseApiModel? response = await HttpHelper.post(
        '/api/business/translate/initiate',
        data: {
          "fileId": fileId,
          "sourceLanguage": sourceLanguage,
          "targetLanguage": targetLanguage,
        },
      );

      if (response?.code != 200) {
        throw response?.msg ?? 'translate failed'.tr;
      }
      return true;
    } catch (e) {
      DialogHelper.showToastDialog(e.toString());
      return false;
    }
  }

  /// 查询音频文件的翻译结果
  static Future<String> getTranslateResult({
    required String fileId,
    required String targetLanguage,
  }) async {
    try {
      final ResponseApiModel? response = await HttpHelper.get(
        '/api/business/file/translate/result',
        queryParameters: {"fileId": fileId, 'targetLanguage': targetLanguage},
      );

      if (response?.code != 200) {
        throw response?.msg ?? 'translate failed'.tr;
      }
      return response?.data ?? '';
    } catch (e) {
      DialogHelper.showToastDialog(e.toString());
      return '';
    }
  }

  /// 查询翻译历史
  static Future<List<TranslateHistoryModel>> getTranslateHistory({
    required String fileId,
    required String textType,
  }) async {
    try {
      final ResponseApiModel? response = await HttpHelper.get(
        '/api/business/translate/history',
        queryParameters: {"fileId": fileId, "textType": textType},
      );

      if (response?.code != 200) {
        throw response?.msg ?? 'translate history failed'.tr;
      }
      return response?.data ?? [];
    } catch (e) {
      DialogHelper.showToastDialog(e.toString());
      return [];
    }
  }

  /// 查询转录语言列表
  static Future<List<TranscriptionLanguageModel>> getTranscriptionLanguageList({
    String? fileId,
    String? textType,
  }) async {
    try {
      final ResponseApiModel? response = await HttpHelper.get(
        '/api/business/translate/languages',
        queryParameters: {"fileId": fileId, "textType": textType},
      );

      if (response?.code != 200) {
        throw response?.msg ?? 'transcription language list failed'.tr;
      }

      final List<dynamic> list = response?.data ?? [];
      // 安全地将 List<dynamic> 转换为 List<Map<String,dynamic>>
      final List<Map<String, dynamic>> languageMaps =
          list.whereType<Map<String, dynamic>>().toList();
      // 按照sortOrder属性倒序排序
      languageMaps.sort((a, b) {
        final sortOrderA = a["sortOrder"] ?? 0;
        final sortOrderB = b["sortOrder"] ?? 0;
        return sortOrderA.compareTo(sortOrderB);
      });
      return languageMaps
          .map((e) => TranscriptionLanguageModel.fromJson(e))
          .toList();
    } catch (e) {
      DialogHelper.showToastDialog(e.toString());
      return [];
    }
  }

  /// 查询prompt模板类别分组列表
  static Future<List<Map<String, dynamic>>>
  getPromptTemplateCategoryList() async {
    try {
      final ResponseApiModel? response = await HttpHelper.get(
        '/api/business/translate/prompt/categories',
      );

      if (response?.code != 200) {
        throw response?.msg ?? 'prompt template category list failed'.tr;
      }

      // 安全地处理数据转换
      final data = response?.data;
      if (data == null) {
        return [];
      }

      // 确保 data 是 List 类型
      if (data is List) {
        // 创建一个新的 List<Map<String, dynamic>>
        final List<Map<String, dynamic>> list = [];

        // 逐个转换元素
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            list.add(item);
          } else if (item is Map) {
            // 如果是其他类型的 Map，转换为 Map<String, dynamic>
            list.add(Map<String, dynamic>.from(item));
          }
        }

        return list;
      } else {
        // 如果 data 不是 List 类型，返回空列表
        return [];
      }
    } catch (e) {
      print('getPromptTemplateCategoryList error: $e');
      DialogHelper.showToastDialog(e.toString());
      return [];
    }
  }

  /// 接口调用发起总结
  static Future<String?> reprocessByAIPrompt({
    required ProcessType aiTaskType,
    required String fileId,
    required String templateId,
    String? teamId,
    bool? isOnlyMe,
  }) async {
    try {
      final ResponseApiModel? response = await HttpHelper.post(
        '/api/business/file/ai',
        data: {
          "aiTaskType": aiTaskType.name,
          "fileId": fileId,
          "teamId": teamId ?? '',
          "isOnlyMe": isOnlyMe ?? false ? 1 : 0,
          "templateId": templateId,
        },
      );

      if (response?.code != 200) {
        throw response?.msg ?? 'prompt ai excute failed'.tr;
      }
      return response?.data;
    } catch (e) {
      DialogHelper.showToastDialog(e.toString());
      return null;
    }
  }
}

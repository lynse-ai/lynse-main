import 'dart:typed_data';

import 'package:dting/http/http_helper.dart';
import 'package:dting/model/baseapi/response_api_model.dart';
import 'package:dting/model/file_model/file_management_model/count_category_file_model.dart';
import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/model/file_model/file_processing_model/edit_trans_model.dart';
import 'package:dio/dio.dart';
import 'package:dting/model/file_model/file_processing_model/share_model.dart';
import 'package:dting/utils/local_sqldb.dart';
import 'package:dting/widgets/dialog/dialog.dart';

enum CheckAction {
  FILE_UPLOAD,
  CREATE_TEAM,
  EDIT_USER,
  EDIT_TEAM,
  EDIT_PERSONAL_FILE,
  EDIT_TEAM_FILE,
  INITIATE_TRANSCRIPTION,
  EDIT_TRANSCRIPTION,
  EDIT_CONCLUSION,
  EDIT_OUTLINE,
  EDIT_DEVICE,
  EDIT_FILE_NAME,
  EDIT_FOLDER_FILE_NAME,
  CREATE_FOLDER,
  EDIT_FOLDER,
}

enum AiTaskStatus { RUNNING, SUCCESS, FAILED }

class FileService {
  // FileService._();
  //文件管理

  /// 获取AI任务状态
  static Future<AiTaskStatus> getAiTaskStatus({
    required String fileId,
    required String taskId,
    required String aiTaskType,
  }) async {
    try {
      final ResponseApiModel? response = await HttpHelper.post(
        '/api/business/file/ai/result',
        data: {'fileId': fileId, 'taskId': taskId, 'aiTaskType': aiTaskType},
      );

      if (response == null || response.code != 200) {
        throw response?.msg ?? '获取AI任务状态失败';
      }

      final String responseStatus = response.data['status'];
      return AiTaskStatus.values.firstWhere(
        (element) => element.name == responseStatus,
      );
    } catch (e) {
      DialogHelper.showToastDialog(e.toString());
    }
    return AiTaskStatus.FAILED;
  }

  /// 检测文本是否合法
  static Future<bool> checkTextValidity(String text, CheckAction action) async {
    try {
      final ResponseApiModel? response = await HttpHelper.post(
        '/api/business/audit/text',
        data: {'text': text, 'actionType': action.name},
      );

      if (response == null || response.code != 200) {
        throw response?.msg ?? '检测文本是否合法失败';
      }

      return response.data;
    } catch (e) {
      DialogHelper.showToastDialog(e.toString());
    }
    return false;
  }

  //文件列表按类型查询
  static Future<List<FileInfoModel>> getFileByCategory({
    String? folderId,
    required String category,
    int? pageSize,
    int? pageNum,
  }) async {
    List<FileInfoModel> returnData = [];

    await HttpHelper.get(
      '/api/business/file/category/list',
      queryParameters: {"category": category},
    ).then((value) async {
      if (value != null && value.data != null) {
        returnData = List<FileInfoModel>.from(
          value.data.map((x) => FileInfoModel.fromJson(x)),
        );
      }
    });
    return returnData;
  }

  //按类型统计
  static Future<FileCountByCategoryModel?> fileCountByCategory() async {
    FileCountByCategoryModel? returnData;

    await HttpHelper.get('/api/business/file/category/count').then((value) {
      if (value != null && value.data != null) {
        returnData = FileCountByCategoryModel.fromJson(value.data);
      }
    });
    return returnData;
  }

  //文件列表查询
  static Future<List<FileInfoModel>> searchFileList({
    String? fileName,
    String? customerId,
    String? nickname,
  }) async {
    List<FileInfoModel> returnData = [];

    await HttpHelper.get(
      '/api/business/file/list',
      queryParameters: {"fileName": fileName, "nickname": nickname},
    ).then((value) {
      if (value != null && value.code == 200 && value.data != null) {
        returnData = List<FileInfoModel>.from(
          value.data.map((x) => FileInfoModel.fromJson(x)),
        );
      }
    });
    return returnData;
  }

  //移动文件
  static Future<ResponseApiModel?> moveFile({
    String? oldFolderId,
    String? newFolderId,
    required String fileIds,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.get(
      '/api/business/file/changeFolder',
      queryParameters: {
        "oldFolderId": oldFolderId,
        "newFolderId": newFolderId,
        "fileIds": fileIds,
      },
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  //编辑文件
  static Future<ResponseApiModel?> editFile({
    required String fileId,
    required String filename,
  }) async {
    ResponseApiModel? returnData;
    await HttpHelper.put(
      '/api/business/file/$fileId',
      queryParameters: {"fileId": fileId},
      data: {"newOriginalFilename": filename},
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  //文件信息
  static Future<FileInfoModel?> fileDetail({required String fileId}) async {
    FileInfoModel? returnData;

    await HttpHelper.get(
      '/api/business/file/info',
      queryParameters: {"fileId": fileId},
    ).then((value) {
      if (value != null && value.data != null) {
        returnData = FileInfoModel.fromJson(value.data);
      }
    });
    return returnData;
  }

  //头像上传
  static Future<String?> uploadAvatar({
    required Uint8List uploadPathBytes,
    required String filename,
  }) async {
    String? returnData;

    await HttpHelper.post(
      '/api/business/file/presign/uploadPublic',
      queryParameters: {"filename": filename},
    ).then((value) async {
      if (value != null && value.code == 200) {
        if (value.data["url"] != null) {
          await uploadOSSFile(
            uploadPathBytes: uploadPathBytes,
            url: value.data["url"],
            contentType: value.data["headers"]["Content-Type"],
          ).then((val) {
            returnData = value.data["url"];
          });
        }
      }
    });

    return returnData;
  }

  static Future<void> insertLocalDB(
    String locaPath, {
    required String fileId,
    required String httpUrl,
  }) async {
    var record = await SqlDBHelper.hasLocalization(fileId);
    try {
      if (record.isNotEmpty) {
        SqlDBHelper.updateData(fildId: fileId, updateLocalUrl: locaPath);
      } else {
        SqlDBHelper.insertRead(
          fildId: fileId,
          httpVoiceUrl: httpUrl,
          localVoiceUrl: locaPath,
        );
      }
    } catch (e) {
      print("放入本地数据库失败");
    }
  }

  //发起转写
  static Future<void> uploadOssSuccnotify({required String fileId}) async {
    await HttpHelper.get(
      '/api/business/file/upload/notify',
      queryParameters: {"fileId": fileId},
    );
  }

  //文件上传 SearchFileByCategoryModel
  static Future<bool> uploadOSSFile({
    required String url,
    required Uint8List uploadPathBytes,
    required String contentType,
  }) async {
    bool returnData = false;
    // 4. 上传到 OSS
    print(url);
    await Dio()
        .put(
          url,
          data: uploadPathBytes,
          options: Options(
            headers: {
              'Content-Type': contentType,
              'Content-Length': uploadPathBytes.length,
            },
          ),
        )
        .then((value) {
          if (value.statusCode == 200) {
            returnData = true;
          }
        });
    return returnData;
  }

  //文件下载/预览（使用URL下载）
  static Future<ResponseApiModel?> downloadFile({
    String? fileId,
    required String sourceType,
    String? url,
    String? localSavePath,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.get(
      '/api/business/file/presign/download',
      queryParameters: {"fileId": fileId, "sourceType": sourceType},
    ).then((value) async {
      returnData = value;
    });

    return returnData;
  }

  //发起转写
  static Future<ResponseApiModel?> transResponse({
    required String fileId,
    required String templateId,
    String? teamId,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/business/file/trans',
      queryParameters: {
        "fileId": fileId,
        "teamId": teamId,
        "templateId": templateId,
      },
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //编辑转写结果
  static Future<ResponseApiModel?> editTransList(
    List<EditTransModel> needEditTransList,
  ) async {
    ResponseApiModel? returnData;
    final editTransList = needEditTransList.map((e) => e.toJson()).toList();
    await HttpHelper.put(
      '/api/business/file/trans/edit',
      data: editTransList,
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //导出转写内容
  static Future<ResponseApiModel?> exportFile({
    required String fileId,
    String exportType = "TXT",
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.getTXT(
      '/api/business/file/trans/export',
      queryParameters: {"fileId": fileId, "exportType": exportType},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //查询转写结果
  static Future<ResponseApiModel?> getTrans({
    required String fileId,
    String? taskId,
    String? teamId,
  }) async {
    ResponseApiModel? returnData;
    await HttpHelper.get(
      '/api/business/file/trans/get',
      queryParameters: {"taskId": taskId, "teamId": teamId, "fileId": fileId},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //获取总结
  static Future<ResponseApiModel?> getConclusion({
    required String fileId,
    String? teamId,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.get(
      '/api/business/file/conclusion/get',
      queryParameters: {"fileId": fileId, "teamId": teamId},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //获取概括
  static Future<ResponseApiModel?> getOutline({
    required String fileId,
    String? teamId,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.get(
      '/api/business/file/outline/get',
      queryParameters: {"fileId": fileId, "teamId": teamId},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //获取思维导图
  static Future<ResponseApiModel?> getMinMap({
    required String fileId,
    String? teamId,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.get(
      '/api/business/file/mindMap/get',
      queryParameters: {"fileId": fileId, "teamId": teamId},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //编辑总结
  static Future<ResponseApiModel?> editSummary({
    required String conclusionId,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.put(
      '/api/business/file/conclusion/$conclusionId',
      queryParameters: {"conclusionId": conclusionId},
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  //编辑概括
  static Future<ResponseApiModel?> editOutline({
    required String outlineId,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.get(
      '/api/business/file/outline/$outlineId',
      queryParameters: {"outlineId": outlineId},
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  //编辑思维导图
  static Future<ResponseApiModel?> editMinMap({
    required String mindMapId,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.put(
      '/api/business/file/mindMap/$mindMapId',
      queryParameters: {"mindMapId": mindMapId},
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  //更改文件状态 已读、未读
  static Future<bool> markRead({required String fileId}) async {
    bool returnData = false;

    await HttpHelper.get(
      '/api/business/file/markRead',
      queryParameters: {"fileId": fileId},
    ).then((value) {
      if (value != null && value.code == 200) {
        returnData = value.data;
      }
    });

    return returnData;
  }

  //文件分享
  static Future<ShareModel?> shareVoice({
    required String sourceType,
    String? fileId,
    String? teamId,
    int? includeTranscription,
    int? includeConclusion,
    int? includeAudioRecording,
    int? includeMindMap,
  }) async {
    try {
      ShareModel? returnData;

      final ResponseApiModel? response = await HttpHelper.post(
        '/api/business/share',
        data: {
          "sourceType": sourceType,
          "fileId": fileId,
          "teamId": teamId,
          "includeTranscription": includeTranscription,
          "includeConclusion": includeConclusion,
          "includeAudioRecording": includeAudioRecording,
          "includeMindMap": includeMindMap,
        },
      );

      if (response == null || response.code != 200 || response.data == null) {
        throw response?.msg ?? "";
      }
      returnData = ShareModel.fromJson(response.data);
      return returnData;
    } catch (e) {
      print('----分享连接失败: ${e.toString()}');
      DialogHelper.showToastDialog(e.toString());
      return null;
    }
  }

  //通过分享码获取分享信息
  static Future<bool> getShareUrl({required String shareId}) async {
    bool returnData = false;

    await HttpHelper.get(
      '/api/business/share/$shareId',
      queryParameters: {"shareId": shareId},
    ).then((value) {
      if (value != null && value.code == 200) {
        returnData = value.data;
      }
    });

    return returnData;
  }
}

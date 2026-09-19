import 'package:dting/http/http_helper.dart';
import 'package:dting/model/baseapi/response_api_model.dart';
import 'package:dting/model/file_model/folder_management_model/change_folder_index_model.dart';
import 'package:dting/model/file_model/folder_management_model/folder_model.dart';
import 'package:dting/widgets/dialog/dialog.dart';

class FolderService {
  FolderService._();

  //文件夹列表
  static Future<List<FolderInfo>> folderList({
    String? folderId,
    String? nickname,
    String? color,
    String? customerId,
  }) async {
    List<FolderInfo> returnData = [];

    await HttpHelper.get(
      '/api/business/file/folder/list',
      queryParameters: {
        "folderId": folderId,
        "nickname": nickname,
        "color": color,
        "customerId": customerId,
      },
    ).then((value) {
      if (value != null && value.data != null) {
        returnData = List<FolderInfo>.from(
          value.data.map((x) => FolderInfo.fromJson(x)),
        );
      }
    });
    return returnData;
  }

  static Future<FolderInfo?> searchFolder({required String folderId}) async {
    FolderInfo? returnData;

    await HttpHelper.get(
      '/api/business/file/folder/$folderId',
      queryParameters: {"folderId": folderId},
    ).then((value) {
      if (value != null && value.data != null) {
        returnData = FolderInfo.fromJson(value.data);
      }
    });
    return returnData;
  }

  //新增数据
  static Future<ResponseApiModel?> createFolder({
    required String folderName,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/business/file/folder/add',
      data: {"folderName": folderName},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //修改数据
  static Future<ResponseApiModel?> editFolder({
    required String folderName,
    String? color,
    required String folderId,
  }) async {
    ResponseApiModel? returnData;
    await HttpHelper.put(
      '/api/business/file/folder/$folderId',
      queryParameters: {"id": folderId},
      data: {"folderName": folderName, "color": color},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //删除文件/文件夹
  static Future<ResponseApiModel?> deleteFile({
    required List<String> fileIds,
    required List<String> folderIds,
  }) async {
    ResponseApiModel? returnData;
    String fileIdString = fileIds.join(',');
    String folderIdString = folderIds.join(',');

    await HttpHelper.delete(
      '/api/business/file/delete',
      queryParameters: {"fileIds": fileIdString, "folderIds": folderIdString},
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  //修改文件夹顺序
  static Future<bool> editFolderIndex(
    List<ChangeFodlerIndexModel> changeIndexList,
  ) async {
    try {
      final editIndexList = changeIndexList.map((e) => e.toJson()).toList();
      ResponseApiModel? response = await HttpHelper.put(
        '/api/business/file/folder/batch-update-sort',
        data: {"folderSortList": editIndexList},
      );

      if (response == null || response.code != 200) {
        throw response?.total ?? "";
      }
      return response.data as bool;
    } catch (e) {
      DialogHelper.showToastDialog(e.toString());
    }
    return false;

    // .then((value) {
    //   if (value != null && value.code == 200) {
    //     returnData = true;
    //   }
    // });
    // return returnData;
  }
}

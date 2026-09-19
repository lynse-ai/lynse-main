import 'package:dting/http/http_helper.dart';
import 'package:dting/model/baseapi/response_api_model.dart';

class BinService {
  BinService._();

  //恢复文件
  static Future<ResponseApiModel?> recoverFile({
    required String fileIds,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.get(
      '/api/business/file/recover',
      queryParameters: {"fileIds": fileIds},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  static Future<bool> deleteBinFile({required String fileIds}) async {
    bool returnData = false;

    await HttpHelper.get(
      '/api/business/file/cleanBin',
      queryParameters: {"fileIds": fileIds},
    ).then((value) {
      if (value != null && value.data != null) {
        returnData = value.data;
      }
    });
    return returnData;
  }
}

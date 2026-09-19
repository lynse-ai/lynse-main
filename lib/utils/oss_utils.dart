import 'package:dting/http/http_helper.dart';
import 'package:dting/model/file_model/file_management_model/sts_credential_model.dart';
import 'package:dting/model/file_model/file_management_model/upload_file_model.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:get/get.dart';
import 'package:flutter_oss_aliyun/flutter_oss_aliyun.dart';
import 'package:dio/dio.dart';

class OssConfig {
  final String bucketName;
  final String endpoint;
  final String accessKeyId;
  final String accessKeySecret;
  final String expire;
  final String token;

  OssConfig({
    required this.bucketName,
    required this.endpoint,
    required this.accessKeyId,
    required this.accessKeySecret,
    required this.expire,
    required this.token,
  });
}

class OssTokenData {
  final String token;
  final String expire;
  final String accessKeyId;
  final String accessKeySecret;

  OssTokenData({
    required this.token,
    required this.expire,
    required this.accessKeyId,
    required this.accessKeySecret,
  });
}

class OssUtilsService extends GetxService {
  static Client? _ossClient;
  OssConfig? ossConfig;

  // 获取临时凭证
  static Future<StsCredentialModel?> getStsCredential(
    UploadFileModel getToken,
  ) async {
    try {
      final response = await HttpHelper.post(
        '/api/business/file/getStsToken',
        data: {
          "saveFilename": getToken.saveFilename,
          "objectType": getToken.objectType,
          "folderId": getToken.folderId,
          "macAddress": getToken.macAddress,
          "mode": getToken.mode,
          "fileSize": getToken.fileSize,
          "bizDuration": getToken.bizDuration,
          "teamId": getToken.teamId,
          "recordStartTime": getToken.recordStartTime,
        },
      );
      if (response == null || response.code != 200) {
        throw response?.msg ?? "获取STS凭证失败";
      }
      print("----getStsCredential response: ${response.data}");
      final data = response.data as Map<String, dynamic>;
      return StsCredentialModel.fromJson(data);
    } catch (e) {
      print("----getStsCredential err: $e");
      return null;
    }
  }

  Auth _authGetter() {
    return Auth(
      accessKey: ossConfig!.accessKeyId,
      accessSecret: ossConfig!.accessKeySecret,
      expire: ossConfig!.expire,
      secureToken: ossConfig!.token,
    );
  }

  Future<void> _initOssClient({
    required String token,
    required String expire,
    required String accessKeyId,
    required String accessKeySecret,
    required String endpoint,
    required String bucketName,
  }) async {
    try {
      ossConfig = OssConfig(
        accessKeyId: accessKeyId,
        accessKeySecret: accessKeySecret,
        endpoint: endpoint,
        bucketName: bucketName,
        expire: expire,
        token: token,
      );
    } catch (e) {
      print('-----init oss client err: $e');
    }

    final dio = Dio();

    _ossClient = Client.init(
      dio: dio,
      ossEndpoint: ossConfig!.endpoint, //"oss-cn-shenzhen.aliyuncs.com",
      bucketName: ossConfig!.bucketName,
      authGetter: _authGetter,
    );
  }

  Future<void> _uploadFile(
    String filePath,
    String objectKey,
    Function? onProgress,
  ) async {
    if (_ossClient == null) {
      throw Exception('----OSS Client not initialized');
    }
    try {
      await _ossClient!.putObjectFile(
        filePath,
        fileKey: objectKey,
        option: PutRequestOption(
          onSendProgress: (count, total) {
            // final progress = ((count / total) * 100).toStringAsFixed(2);
            print(
              "====send: count = $count, and total = $total, and progress = ${(count / total) * 100}%",
            );
            // onProgress(double.parse(progress));
          },
        ),
      );
      print('-----File uploaded successfully: $objectKey');
    } catch (e) {
      print('----Error uploading file: $e');
      DialogHelper.showToastDialog("uploadFail");
      rethrow;
    }
  }

  Future<String?> upload({required UploadFileModel updateFile}) async {
    try {
      final StsCredentialModel? stsModel = await getStsCredential(updateFile);

      if (stsModel == null) {
        throw "获取STS凭证失败！";
      }
      // print("------stsModel: ${stsModel.toJson()}");
      await _initOssClient(
        expire: stsModel.expiration,
        token: stsModel.securityToken,
        accessKeyId: stsModel.accessKeyId,
        accessKeySecret: stsModel.accessKeySecret,
        endpoint: stsModel.endpoint!,
        bucketName: stsModel.bucket,
      );

      await _uploadFile(
        updateFile.path!,
        // '${stsModel.objectKey}${updateFile.saveFilename}',
        stsModel.objectKey,
        (progress) {
          print("----upload progress: $progress");
        },
      );
      return stsModel.fileId;
    } catch (e) {
      print("----upload err: $e");
      DialogHelper.showToastDialog("uploadFail");
      return null;
    }
  }
}

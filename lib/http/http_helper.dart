import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dting/model/baseapi/response_api_model.dart';
import 'package:dting/utils/local_database.dart';
import 'http_basic.dart';

class HttpHelper {
  HttpHelper._();

  static void errorHandle(error, stackTrace) {
    print(error);
  }

  static void setToken(String newToken) {
    LocalDataBase().basicBox!.put("token", newToken);
    token = newToken;
    _setTokenIfExists();
  }

  static void _setTokenIfExists() {
    String? locationToken = LocalDataBase().basicBox!.get("token");
    String? language = LocalDataBase().basicBox!.get("language");
    String languageString = "";
    if (locationToken != null && locationToken.isNotEmpty) {
      dio.options.headers['Authorization'] = locationToken;
    }
    if (token.isNotEmpty) {
      dio.options.headers['Authorization'] = token;
    }
    if (language != null) {
      languageString = language;
    } else {
      languageString = "zh-CN";
    }
    dio.options.headers['Accept-Language'] = languageString;
  }

  static Future<ResponseApiModel?> get(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    String contentType = Headers.jsonContentType,
  }) async {
    ResponseApiModel? response;

    dio.options.contentType = contentType;
    _setTokenIfExists();
    await dio
        .get(url, queryParameters: queryParameters, data: data)
        .then((value) {
          response = ResponseApiModel.fromJson(value.data);
        })
        .onError((error, stackTrace) {
          errorHandle(error, stackTrace);
          response = null;
        });

    return response;
  }

  static Future<ResponseApiModel?> getTXT(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    String contentType = Headers.jsonContentType,
  }) async {
    dynamic response;
    _setTokenIfExists();
    await dio
        .get(url, queryParameters: queryParameters, data: data)
        .then((value) {
          response = value;
        })
        .onError((error, stackTrace) {
          errorHandle(error, stackTrace);
          response = null;
        });

    return response;
  }

  static Future<ResponseApiModel?> download({
    String url = "",
    String path = "",
  }) async {
    ResponseApiModel? response;
    await dio
        .download(url, path)
        .then((value) {
          response = ResponseApiModel.fromJson(value.data);
        })
        .onError((error, stackTrace) {
          errorHandle(error, stackTrace);
          response = null;
        });

    return response;
  }

  static Future<ResponseApiModel?> post(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    String contentType = Headers.jsonContentType,
  }) async {
    ResponseApiModel? response;

    dio.options.contentType = contentType;
    _setTokenIfExists();
    await dio
        .post(url, data: data, queryParameters: queryParameters)
        .then((value) {
          response = ResponseApiModel.fromJson(value.data);
        })
        .onError((error, stackTrace) {
          if (error is DioException) {
            if (error.error is SocketException) {
              final socketError = error.error as SocketException;
              var code = socketError.osError?.errorCode;
              if (code != null && code == 65) {
                //
              }
            }
          }
          errorHandle(error, stackTrace);
          response = null;
        });

    return response;
  }

  static Future<ResponseApiModel?> delete(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    String contentType = Headers.jsonContentType,
  }) async {
    ResponseApiModel? response;

    dio.options.contentType = contentType;
    _setTokenIfExists();

    await dio
        .delete(url, data: data, queryParameters: queryParameters)
        .then((value) {
          response = ResponseApiModel.fromJson(value.data);
        })
        .onError((error, stackTrace) {
          errorHandle(error, stackTrace);
          response = null;
        });

    return response;
  }

  static Future<ResponseApiModel?> put(
    String url, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    String contentType = Headers.jsonContentType,
  }) async {
    ResponseApiModel? response;

    dio.options.contentType = contentType;
    _setTokenIfExists();

    await dio
        .put(url, queryParameters: queryParameters, data: data)
        .then((value) {
          response = ResponseApiModel.fromJson(value.data);
        })
        .onError((error, stackTrace) {
          errorHandle(error, stackTrace);
          response = null;
        });

    return response;
  }

  static Future<File> downloadFile(
    String url,
    String savePath, {
    Function(double progress)? onProgress,
  }) async {
    final httpClient = HttpClient();
    late File file;
    int bytesDownloaded = 0;

    try {
      // 确保保存目录存在
      final directory = Directory(savePath).parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw Exception('下载失败: 状态码 ${response.statusCode}');
      }

      file = File(savePath);
      final sink = file.openWrite();

      await for (final chunk in response) {
        bytesDownloaded += chunk.length;
        sink.add(chunk);

        // 计算并回调进度
        if (response.contentLength != -1 && onProgress != null) {
          final progress = bytesDownloaded / response.contentLength;
          onProgress(progress);
        }
      }

      await sink.close();
      return file;
    } on SocketException catch (e) {
      throw Exception('网络错误: 无法连接到服务器 - ${e.message}');
    } on IOException catch (e) {
      throw Exception('文件操作错误: 无法写入文件 - ${e.toString()}');
    } catch (e) {
      throw Exception('下载失败: $e');
    } finally {
      httpClient.close();
      // 如果下载失败且文件已创建，删除不完整文件
      if (file.existsSync() && bytesDownloaded < (await file.length())) {
        await file.delete();
      }
    }
  }
}

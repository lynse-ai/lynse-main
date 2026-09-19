import 'dart:io';
import 'package:dting/model/file_model/file_processing_model/share_model.dart';
import 'package:dting/service/file_service.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:fluwx/fluwx.dart' as fluwx;

class ShareUtil {
  /// 分享文本
  static Future<void> shareUrl(String url, {String? fileName}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(uri: Uri.parse(url), title: fileName, subject: fileName),
      );
    } catch (e) {
      DialogHelper.showToastDialog(e.toString());
      print("分享失败 shareUrl:$e");
    }
  }

  /// 分享文本
  static Future<void> shareText(
    String text, {
    String? subject,
    String? fileName,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: subject, title: fileName),
      );
    } catch (e) {
      print("分享失败 shareText:$e");
    }
  }

  ///分享文件（如 PDF、Word、Excel 图片等） （本地路径）
  static Future<void> shareFile(
    String filePath, {
    String? text,
    String? fileName,
  }) async {
    try {
      final box = XFile(filePath);
      await SharePlus.instance.share(
        ShareParams(files: [box], text: text, title: fileName),
      );
    } catch (e) {
      print("分享失败 shareFile:$e");
    }
  }

  /// 分享多个文件、图片
  static Future<void> shareFiles(
    List<String> imagePaths, {
    String? text,
    String? fileName,
  }) async {
    try {
      final files = imagePaths.map((path) => XFile(path)).toList();
      await SharePlus.instance.share(
        ShareParams(files: files, text: text, title: fileName),
      );
    } catch (e) {
      print("分享失败 shareFiles:$e");
    }
  }

  //微信分享
  static Future<void> shareWechat() async {
    try {
      fluwx.WeChatShareTextModel("这是一段测试文本", scene: fluwx.WeChatScene.session);
    } catch (e) {
      print("分享失败 shareWechat:$e");
    }
  }

  //下载文件然后分享
  static Future<void> exportFile({
    required String content,
    required String type,
    required String fileName,
    String suffix = "text",
  }) async {
    try {
      String savePath = "";
      var downloadsPath = await getApplicationCacheDirectory();

      savePath = '${downloadsPath.path}/$fileName.$suffix';

      final jsonFile = File(savePath);
      final exist = await jsonFile.exists();
      if (exist) {
        await jsonFile.writeAsString(content);
      } else {
        jsonFile.create(recursive: true);
        await jsonFile.writeAsString(content);
      }

      await shareFile(savePath, fileName: fileName);
    } catch (e) {
      print("导出文件错误$e");
    }
  }

  //通过链接分享
  static Future<ShareModel?> shareVoiceByUrl({
    required String sourceType,
    String? fileId,
    String? teamId,
    int? includeTranscription,
    int? includeConclusion,
    int? includeOutline,
    int? includeMindMap,
    int? includeAudioRecording,
  }) async {
    ShareModel? share;
    await FileService.shareVoice(
      sourceType: sourceType,
      fileId: fileId,
      teamId: teamId,
      includeTranscription: includeTranscription,
      includeConclusion: includeConclusion,
      includeAudioRecording: includeAudioRecording,
      includeMindMap: includeMindMap,
    ).then((val) {
      if (val != null) {
        share = val;
      }
    });
    return share;
  }

  //导出音频
  static Future<void> downloadFile(
    String? localSavePath,
    String? filename,
    String value,
    String fileId,
  ) async {
    try {
      String savePath = '$localSavePath/$filename.mp3';
      final jsonFile = File(savePath);
      final exist = await jsonFile.exists();
      if (exist) {
        var response = await http.get(Uri.parse(value));
        var bytes = response.bodyBytes;
        await jsonFile.writeAsBytes(bytes);
      } else {
        var response = await http.get(Uri.parse(value));
        var bytes = response.bodyBytes;
        await File(savePath).create(recursive: true).then((file) async {
          await file.writeAsBytes(bytes);
        });
      }
      ShareUtil.shareFile(savePath, fileName: filename);
    } catch (e) {
      print("导出音频失败$e");
    }
  }
}

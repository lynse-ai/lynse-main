import 'dart:convert';
import 'dart:io';

import 'package:dting/model/file_model/file_processing_model/share_model.dart';
import 'package:dting/pages/device/audio_sure/share_util.dart';
import 'package:dting/pages/device/voice_details/voicedetails_controller.dart';
import 'package:dting/service/file_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/base64_util.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:get/get.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class AudioSureController extends GetxController {
  List<Map<String, String>> shareDocumentMenu = [
    {"assetname": "assets/assets/documents2.png", "title": "Copytrans"},
    {
      "assetname": "assets/assets/documents2.png",
      "title": "ReplicationOverview",
    },
    {"assetname": "assets/assets/documents2.png", "title": "CopySummary"},
  ];

  var shareUploadMenu = {
    {"assetname": "assets/assets/forgetdevice.png", "title": "ExportAudio"},
    {"assetname": "assets/assets/forgetdevice.png", "title": "ExportTrans"},
    {"assetname": "assets/assets/forgetdevice.png", "title": "ExportOverview"},
    {"assetname": "assets/assets/forgetdevice.png", "title": "ExportSummary"},
    {"assetname": "assets/assets/audio-mind-map.png", "title": "ExportMindMap"},
  };
  var appController = Get.find<DtingStore>();
  var voiceDetailController = Get.find<VoiceDetailsController>();

  var includeTrans = 0.obs; //分享链接是否包含转写
  var includeConcl = 0.obs; //是否包含总结
  var includeMindMap = 0.obs; //是否包含思维导图
  var includVoice = 0.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
  }

  void shareDocumentOnClick(
    String type,
    bool isPersonal, {
    required String fileId,
  }) {
    print(type);
    switch (type) {
      case "Copytrans":
        transHandler(type: "copy", isPersonal: isPersonal, fileId: fileId);
        break;
      case "ReplicationOverview":
        outlinHandler(type: "copy");
        break;
      case "CopySummary":
        conclHandler(type: "copy");
        break;
    }
  }

  void shareUploadMenuOnClick(
    String type, {
    required bool isPersonal,
    required String fileId,
  }) {
    print(type);

    switch (type) {
      case "ExportAudio":
        exportVoice(pathType: "download", isPersonal: isPersonal);
        break;
      case "ExportTrans":
        transHandler(type: "export", isPersonal: isPersonal, fileId: fileId);
        break;
      case "ExportOverview":
        outlinHandler(type: "export");
      case "ExportSummary":
        conclHandler(type: "export");
        break;
      case "ExportMindMap":
        if (voiceDetailController.conclData.value.conclusionText == null ||
            voiceDetailController.conclData.value.conclusionText == "" ||
            !voiceDetailController.haveMindMapData.value) {
          DialogHelper.showToastDialog(
            "notDownload".trParams({'menu': "MindMapped".tr}),
          );
          return;
        }
        exportMindMapImage();
        break;
    }
  }

  Future<void> transHandler({
    required String type,
    required bool isPersonal,
    required String fileId,
  }) async {
    //转写没有数据复制以及下载提示
    if (voiceDetailController.transcrSpeakList.isEmpty) {
      if (type == "copy") {
        DialogHelper.showToastDialog(
          "notCopy".trParams({'menu': "Transcr".tr}),
        );
      } else {
        DialogHelper.showToastDialog(
          "notDownload".trParams({'menu': "Transcr".tr}),
        );
      }
      return;
    }

    await EasyLoading.show();
    String content = "";
    try {
      for (var trans in voiceDetailController.transcrSpeakList) {
        content += "${trans.speakerName} : ${trans.text}\r\n";
      }
      if (type == "copy") {
        copyToClipboard(content);
        Get.back();
      } else {
        Get.back();
        ShareUtil.exportFile(
          content: content,
          type: "trans",
          fileName: appController.selectFileInfo.value.originalFilename!,
        );
      }
    } finally {
      await EasyLoading.dismiss();
    }
  }

  String markdownToPlainText(String markdown) {
    final document = md.Document();
    final nodes = document.parseLines(markdown.split('\n'));
    final buffer = StringBuffer();

    void extractText(md.Node node) {
      if (node is md.Text) {
        buffer.write(node.text);
      }
      if (node is md.Element && node.children != null) {
        for (final child in node.children!) {
          extractText(child);
          if (child is md.Element && child.tag == 'p') {
            buffer.write('\n'); // 段落换行
          }
        }
      }
    }

    for (final node in nodes) {
      extractText(node);
    }

    return buffer.toString();
  }

  Future<void> conclHandler({required String type}) async {
    //总结没有数据复制以及下载提示
    if (voiceDetailController.conclData.value.conclusionText == null ||
        voiceDetailController.conclData.value.conclusionText == "") {
      if (type == "copy") {
        DialogHelper.showToastDialog("notCopy".trParams({'menu': "Concl".tr}));
      } else {
        DialogHelper.showToastDialog(
          "notDownload".trParams({'menu': "Concl".tr}),
        );
      }
      return;
    }

    await EasyLoading.show();
    try {
      final plain = markdownToPlainText(
        voiceDetailController.conclData.value.conclusionText!,
      );
      if (type == "copy") {
        copyToClipboard(plain);
        Get.back();
      } else {
        Get.back();
        ShareUtil.exportFile(
          content: voiceDetailController.conclData.value.conclusionText!,
          type: "concl",
          fileName: appController.selectFileInfo.value.originalFilename!,
          suffix: "md",
        );
      }
    } finally {
      await EasyLoading.dismiss();
    }
  }

  Future<void> outlinHandler({required String type}) async {
    //概要没有数据复制以及下载提示
    if (voiceDetailController.outlnData.value.outlineText == null ||
        voiceDetailController.outlnData.value.outlineText == "") {
      if (type == "copy") {
        DialogHelper.showToastDialog("notCopy".trParams({'menu': "Outln".tr}));
      } else {
        DialogHelper.showToastDialog(
          "notDownload".trParams({'menu': "Outln".tr}),
        );
      }
      return;
    }

    await EasyLoading.show();
    try {
      if (type == "copy") {
        copyToClipboard(voiceDetailController.outlnData.value.outlineText!);
        Get.back();
      } else {
        Get.back();
        ShareUtil.exportFile(
          content: voiceDetailController.outlnData.value.outlineText!,
          type: "outlin",
          fileName: appController.selectFileInfo.value.originalFilename!,
        );
      }
    } finally {
      await EasyLoading.dismiss();
    }
  }

  void copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    DialogHelper.showToastDialog("copySuccess");
  }

  //下载录音文件
  void exportVoice({String pathType = "", required bool isPersonal}) async {
    Get.back();
    //这个是下载路径
    try {
      String path = "";
      var downloadsPath = await getApplicationDocumentsDirectory();
      path = "${downloadsPath.path}/download";

      if (appController.selectFileInfo.value.id != null &&
          appController.selectFileInfo.value.id!.isNotEmpty) {
        var tempString = "PERSONAL";
        if (!isPersonal) {
          tempString = "TEAM";
        }
        FileService.downloadFile(
          fileId: appController.selectFileInfo.value.id,
          localSavePath: path,
          sourceType: tempString,
        ).then((res) async {
          if (res != null && res.data != null) {
            await ShareUtil.downloadFile(
              path,
              appController.selectFileInfo.value.originalFilename,
              res.data,
              appController.selectFileInfo.value.id!,
            );
          }
        });
      }
    } catch (e) {
      print("分享文件在下载到本地时失败$e");
    }
  }

  //调用本地系统分享
  void shareLinkToOther(bool isPersonal) async {
    // 分享纯文本或链接
    if (includVoice.value == 0 &&
        includeTrans.value == 0 &&
        includeMindMap.value == 0 &&
        includeConcl.value == 0) {
      DialogHelper.showToastDialog("cantShareLink");
      return;
    }
    Get.back();
    try {
      var fileSourceTypeString = "PERSONAL";
      String? teamId;

      if (!isPersonal) {
        fileSourceTypeString = 'TEAM';
        teamId = appController.userInfo.value.teamId;
      }

      ShareModel? val = await FileService.shareVoice(
        fileId: appController.selectFileInfo.value.id,
        sourceType: fileSourceTypeString,
        teamId: teamId,
        includeConclusion: includeConcl.value,
        includeTranscription: includeTrans.value,
        includeMindMap: includeMindMap.value,
        includeAudioRecording: includVoice.value,
      );

      if (val != null && val.shareUrl != null) {
        ShareUtil.shareUrl(
          val.shareUrl!,
          fileName: appController.selectFileInfo.value.originalFilename ?? "",
        );
      }

      // .then((val) {
      //   if (val != null && val.shareUrl != null) {
      //     ShareUtil.shareUrl(
      //       val.shareUrl!,
      //       fileName: appController.selectFileInfo.value.originalFilename ?? "",
      //     );
      //   } else {
      //     DialogHelper.showToastDialog("shareFail");
      //   }
      // });
    } catch (e) {
      print("=====通过链接分享失败$e");
    }
  }

  //复制链接
  void copyLink(bool isPersonal) {
    if (includVoice.value == 0 &&
        includeTrans.value == 0 &&
        includeMindMap.value == 0 &&
        includeConcl.value == 0) {
      DialogHelper.showToastDialog("cantShareLink");
      return;
    }
    Get.back();
    try {
      // 分享纯文本或链接
      var fileSourceTypeString = "PERSONAL";
      String? teamId;

      if (!isPersonal) {
        fileSourceTypeString = 'TEAM';
        teamId = appController.userInfo.value.teamId;
      }
      FileService.shareVoice(
        fileId: appController.selectFileInfo.value.id,
        sourceType: fileSourceTypeString,
        teamId: teamId,
        includeConclusion: includeConcl.value,
        includeTranscription: includeTrans.value,
        includeMindMap: includeMindMap.value,
        includeAudioRecording: includVoice.value,
      ).then((val) {
        if (val != null && val.shareUrl != null) {
          //copy link
          copyToClipboard(val.shareUrl!);
        }
      });
    } catch (e) {
      print("获取分享链接失败$e");
      DialogHelper.showToastDialog("copyShare");
    }
  }

  Future<void> exportMindMapImage() async {
    final String imgData = await voiceDetailController.exportImage(type: 'png');

    try {
      // 构建文件名和存放文件路径
      final downloadsPath = await getApplicationDocumentsDirectory();
      String savePath =
          "${downloadsPath.path}/${appController.selectFileInfo.value.originalFilename}.png";

      // 文件判断
      final imgFile = File(savePath);
      final exist = await imgFile.exists();
      if (!exist) {
        imgFile.create(recursive: true);
      }

      // 步骤1：清理非法字符
      String cleaned = cleanBase64(imgData);
      // 步骤2：修正填充
      String padded = fixPadding(cleaned);
      // 步骤3：解码
      Uint8List bytes = base64Decode(padded);
      if (padded == "data" || padded.isEmpty) {
        DialogHelper.showToastDialog(
          "notDownload".trParams({'menu': "MindMapped".tr}),
        );
        return;
      }
      await imgFile.writeAsBytes(bytes);

      ShareUtil.shareFile(
        savePath,
        fileName: appController.selectFileInfo.value.originalFilename,
      );
    } catch (e) {
      print('Error exporting image: $e');
      DialogHelper.showToastDialog("mindMapFail");
      return;
    }
  }
}

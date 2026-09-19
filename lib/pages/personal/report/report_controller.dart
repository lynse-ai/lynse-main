import 'dart:async';
import 'dart:io';

import 'package:dting/enums/permission_enum.dart';
import 'package:dting/model/personal_model/submit_report_model.dart';
import 'package:dting/service/permission_service.dart';
import 'package:dting/service/personal_service.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class ReportController extends GetxController {
  var reportTextController = TextEditingController();
  var reportPhoneController = TextEditingController();
  var textNumber = 0.obs;
  var imageList = <SubmitReportModel>[].obs; //举报图片
  final picker = ImagePicker();
  @override
  void onInit() {
    super.onInit();
  }

  Future<void> pickImage() async {
    bool hasPermission = await PermissionService.instance.checkPermission(
      PermissionEnum.photos,
    );

    if (hasPermission) {
      // 已授权，直接调图库
      await _pick();
      return;
    }

    // 读本地存储，判断之前是否弹过自定义弹窗
    var hasShownHint = await LocalDataBase().basicBox!.get(
      "hasShownPermissionHint",
    );
    if (!Platform.isIOS) {
      //如果是IOS直接跳过弹窗
      if (hasShownHint == null || !hasShownHint) {
        // 第一次弹自定义提示弹窗
        var temp = await showPermissionHintDialog();
        if (!temp) {
          return;
        }
      }
    }

    // 弹窗点“下一步”或弹窗已弹过后，发起系统权限请求
    bool granted = await PermissionService.instance.requestPhotosPermissions(
      'reportPhotoPermissionRequest'.tr,
    );
    if (granted) {
      await _pick();
    } else {
      // 权限被拒绝，弹引导去设置页的弹窗（可选 ）
      DialogHelper.showToastDialog('photoPermiss2');
    }
  }

  Future<void> _pick() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      imageList.add(SubmitReportModel(mediaUrl: file.path));
    }
  }

  Future<bool> showPermissionHintDialog() {
    final completer = Completer<bool>();

    DialogHelper.showTipDialog(
      message: 'reportMess',
      title: 'reportTip',
      okText: 'permissionAllow',
      okOntap: () {
        LocalDataBase().basicBox!.put('hasShownPermissionHint', true);
        if (!completer.isCompleted) completer.complete(true);
        Get.back();
      },
      cancelText: 'permissionDeny',
      cancelOntap: () {
        if (!completer.isCompleted) completer.complete(false);
        Get.back();
      },
    );

    return completer.future;
  }

  void removeImage(SubmitReportModel path) {
    imageList.remove(path);
  }

  void uploadReport() {
    if (reportTextController.text.trim().isNotEmpty) {
      PersonalService.submitReport(
        content: reportTextController.text,
        mediaList: imageList,
      ).then((val) {
        DialogHelper.showToastDialog("reportSuccessful");
        Get.back();
      });
    } else {
      DialogHelper.showToastDialog("decReport");
    }
  }
}

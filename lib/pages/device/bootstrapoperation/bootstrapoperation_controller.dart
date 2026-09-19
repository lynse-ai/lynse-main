import 'dart:async';

import 'package:dting/plugin/nv_easy_plugin.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BootstrapOperationController extends GetxController
    with GetTickerProviderStateMixin {
  var bootstrapOperationList = [1, 2, 3];
  late AnimationController animationController;
  var isAnimating = false.obs; // 用于跟踪动画是否正在进行

  var appController = Get.find<DtingStore>();

  Timer? _scanTimer;
  bool _isClosed = false;
  @override
  void onInit() {
    super.onInit();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // 指定动画时长
    );
    toggleAnimation();
    appController.isShowScaning = true;
  }

  @override
  void dispose() {
    super.dispose();
    print("BootstrapOperationController Dispose");
  }

  @override
  void onClose() {
    print("BootstrapOperationController onClose");
    appController.isShowScaning = false;
    animationController.dispose();
    _scanTimer?.cancel();
    super.onClose();
  }

  void toggleAnimation() {
    if (isAnimating.value) {
      stopScan();
    } else {
      NvEasyPlugin().startScan();
      animationController.repeat();
      isAnimating.value = true;

      // 启动 5 秒定时器
      _scanTimer = Timer(Duration(seconds: 5), () {
        if (_isClosed) return; // 已销毁就不再执行
        stopScan();
      });
    }
  }

  void stopScan() {
    if (_isClosed || !appController.isShowScaning) return;

    print("BootstrapOperationController Stop Scanning");
    animationController.stop();
    isAnimating.value = false;
    NvEasyPlugin().stopScan();

    Get.back(); // 关闭弹窗
    if (appController.scanDeviceList.isNotEmpty) {
      NavigationUtils.toSearchDevice();
    } else {
      DialogHelper.showToastDialog("notSearchDevices");
    }

    _isClosed = true;
    _scanTimer?.cancel();
    Get.delete<BootstrapOperationController>();
  }
}

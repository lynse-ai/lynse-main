// 文件传输状态组件
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/color_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

class FileTransferStatusWidget extends StatelessWidget {
  final VoidCallback? onQuickTransferPressed;
  final DtingStore controller;

  const FileTransferStatusWidget({
    super.key,
    required this.controller,
    this.onQuickTransferPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.only(top: 10.w),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 进度条和按钮区域
              Row(
                children: [
                  // 进度指示器
                  Expanded(
                    child: Obx(() {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          //进度条
                          buildProgressIndicator(),
                          const SizedBox(height: 4),
                          //下载速率
                          buildProgressStatus(),
                        ],
                      );
                    }),
                  ),
                  // 快传按钮
                  // const SizedBox(width: 12),
                  // buildElevatedButton(),
                ],
              ),
              // 状态文本
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'dtingNote'.tr,
                    style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 快传按钮
  ///
  ///
  ElevatedButton buildElevatedButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: onQuickTransferPressed,
      child: Text('QuickTransfer'.tr),
    );
  }

  /// 下载速度
  ///
  ///
  Row buildProgressStatus() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${controller.currentFile.value.clamp(0, controller.connectDeviceFileList.length)}/${controller.connectDeviceFileList.length}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        Text(
          '${controller.downloadFileSpeed.value.isFinite ? controller.downloadFileSpeed.value.toInt() : 0} KB/S',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  ///下载进度指示器
  ///
  ///
  ClipRRect buildProgressIndicator() {
    // 安全计算进度值，避免除零和无穷大值
    double progress = 0.0;

    // 确保所有值都是有效的数字
    final currentPacket =
        controller.currentPacket.value.isFinite
            ? controller.currentPacket.value
            : 0.0;
    final totalPacket =
        controller.totalPacket.value.isFinite
            ? controller.totalPacket.value
            : 1.0;

    if (totalPacket > 0 && currentPacket >= 0) {
      progress = currentPacket / totalPacket;
      // 确保进度值在0-1范围内
      progress = progress.clamp(0.0, 1.0);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.grey[300],
        color: ColorUtil.fromHexString("#7857ED"),
        minHeight: 8,
      ),
    );
  }
}

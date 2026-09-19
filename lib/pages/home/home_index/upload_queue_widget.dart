import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';

class UploadQueueWidget extends GetView<HomeIndexController> {
  UploadQueueWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.uploadQueue.isEmpty) {
        return SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: controller.uploadQueue.length,
            padding: EdgeInsets.symmetric(vertical: 4.w),
            itemBuilder: (context, index) {
              final item = controller.uploadQueue[index];
              return _buildUploadItem(
                item,
                index == controller.uploadQueue.length - 1,
              );
            },
          ),
        ],
      );
    });
  }

  Widget _buildUploadItem(Map<String, dynamic> item, bool isLast) {
    final status = item['uploadStatus'] as int;
    final filename = item['saveFilename'] as String;
    final id = item['id'] as int;
    final errorMessage = item['errorMessage'] as String?;
    final scene = item['scene'] as int;

    String statusText;
    // Color statusColor;
    String sceneString;
    if (scene == 0) {
      sceneString = "MEETING";
    } else if (scene == 1) {
      sceneString = "CALL";
    } else {
      sceneString = "IMPORT";
    }
    switch (status) {
      case 0: // 待上传
        statusText = 'pending'.tr;
        // statusColor = Colors.orange;
        break;
      case 1: // 上传中
        statusText = 'uploading'.tr;
        // statusColor = Colors.blue;
        break;
      case 2: // 上传成功
        statusText = 'completed'.tr;
        // statusColor = Colors.green;
        break;
      case 3: // 上传失败
        statusText = 'failed'.tr;
        // statusColor = Colors.red;
        break;
      default:
        statusText = 'unknown'.tr;
      // statusColor = Colors.grey;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.w),
      decoration: BoxDecoration(
        color: ColorUtil.fromHexString("#FFFFFF"),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child:
          status == 3
              ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("existFail".tr).descText(),
                      SizedBox(height: 10),
                      Text("failTip".tr).descText(
                        fontSize: 10,
                        color: ColorUtil.fromHexString("#7E8492"),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => controller.retryUpload(id),
                    child: Container(
                      alignment: Alignment.center,
                      height: 24,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      decoration: BoxDecoration(
                        color: ColorUtil.fromHexString("#7857ED"),
                        borderRadius: BorderRadius.circular(50.r),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            "assets/images_v3/reUpload.png",
                            width: 16.w,
                            height: 16.w,
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            'retry'.tr,
                          ).mainTitle(fontSize: 10, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 文件名
                  Text(filename).mainTitle(
                    overflow: TextOverflow.ellipsis,
                    maxLine: 1,
                    fontSize: 17,
                  ),
                  SizedBox(height: 6.w),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        margin: EdgeInsets.only(right: 4.w),
                        padding: EdgeInsets.symmetric(
                          vertical: 2.w,
                          horizontal: 6.w,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ColorUtil.fromHexString("#EAECEF"),
                          borderRadius: BorderRadius.circular(4.w),
                        ),
                        child: Text(
                          sceneString.tr,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ).descText(
                          fontSize: 8,
                          color: ColorUtil.fromHexString("#7E8492"),
                        ),
                      ),
                      Text(statusText).descText(
                        fontSize: 10,
                        color: ColorUtil.fromHexString("#7857ED"),
                      ),
                    ],
                  ),
                ],
              ),
    );
  }
}

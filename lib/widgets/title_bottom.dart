import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class TitleBottomWidget extends GetView {
  TitleBottomWidget({super.key, required this.title});

  String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          alignment: Alignment.center,
          height: 44.w,
          padding: EdgeInsets.only(top: 12.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.tr).boldTitle(fontSize: 16),
              GestureDetector(
                onTap: () {
                  Get.back();
                },
                child: Container(
                  alignment: Alignment.centerRight,
                  width: 30.w,
                  color: ColorUtil.fromHexString("#F2F4F7"),
                  height: Get.height,
                  child: Image.asset(
                    "assets/images_v3/edit-cancel.png",
                    width: 16.w,
                    height: 16.w,
                  ),
                ),
              ),
            ],
          ),
        ),
        DividerWidget(spacer: 10),
      ],
    );
  }
}

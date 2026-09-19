import 'package:dting/router/modules/translate_router.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class AiGeneratorBtnWidget extends StatelessWidget {
  String text;
  bool showIcon;
  AiGeneratorBtnWidget({super.key, required this.text, required this.showIcon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Get.toNamed(
          TranslateRouter.promptListPage,
          arguments: {"isFirstGenerator": false},
        );
      },
      child: Container(
        // height: 78.w,
        padding: EdgeInsets.symmetric(vertical: 12.w),
        child: Container(
          height: 48.w,
          alignment: Alignment.center,
          margin: EdgeInsets.only(top: 8.w),
          width: 240.w,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ColorUtil.fromHexString("#7352DD"),
                ColorUtil.fromHexString("#AB91EA"),
                ColorUtil.fromHexString("#9187E0"),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.40, 0.80],
            ),
            borderRadius: BorderRadius.circular(12),
            color: ColorUtil.fromHexString("#E4E7EC"),
            boxShadow: [
              BoxShadow(
                offset: Offset(10, 14),
                blurRadius: 2,
                spreadRadius: 0,
                color: ColorUtil.fromHexString("#7352DD", 0.13),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              showIcon
                  ? Image.asset(
                    "assets/images_v3/ai-generated.png",
                    width: 24.w,
                    height: 24.w,
                  )
                  : SizedBox.shrink(),
              showIcon ? SizedBox(width: 15.w) : SizedBox.shrink(),
              Text(text.tr).mainTitle(fontSize: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

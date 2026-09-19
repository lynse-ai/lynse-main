import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'language_controller.dart';

class LanguagePage extends GetView<LanguageController> {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidgets.getAppBar(
        title: "language",
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
        gobackOntap: () {
          Get.back();
        },
      ),
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      body: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.only(left: 24.w, right: 24.w, top: 10.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 11.w),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: ColorUtil.fromHexString("#FFFFFF"),
                borderRadius: BorderRadius.circular(10.w),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      controller.showLanguageBottomSheet('applyLanguage');
                    },
                    child: SizedBox(
                      height: 50.w,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("applyLanguage".tr).descText(),
                          Row(
                            children: [
                              Text(controller.applyLangLabel).descText(),
                              SizedBox(width: 10.w),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: ColorUtil.fromHexString("#B2B6BF"),
                                size: 14.w,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // DividerWidget(spacer: 0),

                  // GestureDetector(
                  //   onTap: () {
                  //     controller.showLanguageBottomSheet('transLanguage');
                  //   },
                  //   child: SizedBox(
                  //     height: 50.w,
                  //     child: Row(
                  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //       children: [
                  //         Text("transLanguage".tr).descText(),
                  //         Row(
                  //           children: [
                  //             Text(controller.transLangLabel).descText(),
                  //             SizedBox(width: 10.w),
                  //             Icon(
                  //               Icons.arrow_forward_ios,
                  //               color: ColorUtil.fromHexString("#B2B6BF"),
                  //               size: 14.w,
                  //             ),
                  //           ],
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

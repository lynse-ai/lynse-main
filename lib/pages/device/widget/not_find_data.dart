import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';
import 'package:lottie/lottie.dart';

class NotFindData extends GetView {
  const NotFindData({
    super.key,
    required this.title,
    this.assname = "assets/images_v3/analyze.png",
    this.assnameSize = 40,
    this.info = "analysis",
    this.isShowGetData = true,
    this.ontap,
    this.isExamples,
  });
  final String title;
  final String assname;
  final String info;
  final double assnameSize;
  final bool isShowGetData;
  final Callback? ontap;
  final int? isExamples;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 30.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(assname, width: assnameSize.w, height: assnameSize.w),
              SizedBox(height: 8.w),
              Text(title.tr).mainTitle(fontSize: 18),
              Text(info.tr).descText(
                textAlign: TextAlign.center,
                color: ColorUtil.fromHexString("#858C9B"),
              ),
              isShowGetData
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: ontap,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 78.w,
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
                                      color: ColorUtil.fromHexString(
                                        "#7352DD",
                                        0.13,
                                      ),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      "assets/images_v3/ai-generated.png",
                                      width: 24.w,
                                      height: 24.w,
                                    ),
                                    SizedBox(width: 15.w),
                                    Text("AI-generated".tr).mainTitle(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExamples == 1)
                              Positioned(
                                top: 40,
                                child: Image.asset(
                                  'assets/images_v3/search-guidelines.png',
                                  height: 31.w,
                                  fit: BoxFit.fitHeight,
                                ),
                              ),
                            if (isExamples == 1)
                              Positioned(
                                // right: 25,
                                top: 25,
                                child: Lottie.asset(
                                  'assets/lotties/search.lottie',
                                  width: 48.w,
                                  fit: BoxFit.fitWidth,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                  : SizedBox(),
            ],
          ),
        ),
      ],
    );
  }
}

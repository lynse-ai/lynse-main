import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class NoDataWidget extends GetView {
  NoDataWidget({
    super.key,
    this.assectName = 'assets/images_v3/notfind-file.png',
    this.tipText = 'noFile',
    this.size = 100,
  });
  String assectName;
  String tipText;
  double size;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(assectName, height: size.w, width: size.w),
        SizedBox(height: 10.w),
        Text(tipText.tr).descText(color: ColorUtil.fromHexString("#7D8594")),
        SizedBox(height: 30.w),
      ],
    );
  }
}

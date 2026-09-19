import 'package:dting/utils/color_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; 
import 'package:get/get.dart';

class LoadingWidget extends GetView {
  LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column( 
      children: [
         Image.asset(
          'assets/images/homeindex/nodata.png',
          height: 200.w,
          width: 200.w, 
        ),
        SizedBox(height: 10.w),
        Text(
          'Loading'.tr,
          style: TextStyle(
            color: ColorUtil.fromHexString("#7E8492"),
            fontWeight: FontWeight.w500,
            fontSize: 12.w,
            height: 14.06 / 12,
          ),
        ),
      ],
    );
  }
}

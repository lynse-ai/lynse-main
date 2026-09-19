import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LogoWidget extends StatelessWidget {
  const LogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/starup/dting.png',
          width: 155.86.w,
          height: 35.97.w,
        ),
        // Text(
        //   "Listen to AI, listen to life".tr,
        //   style: TextStyle(
        //     fontWeight: FontWeight.w400,
        //     color: ColorUtil.fromHexString('#5B5E68'),
        //     fontSize: 14.w,
        //     height: 20 / 14,
        //   ),
        // ),
      ],
    );
  }
}

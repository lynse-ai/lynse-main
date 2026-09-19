import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

class GesturedetectorByIcon extends GetView {
  const GesturedetectorByIcon({
    super.key,
    required this.ontap,
    required this.assname,
    this.iconsize = 24,
    this.width,
  });

  final Callback ontap;
  final double iconsize;
  final String assname;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container( 
      width: width,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: ontap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             SvgPicture.asset(assname, height: iconsize.w, width: iconsize.w),
          ],
        ),
      ),
    );
  }
}

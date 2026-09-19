 
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

class IconGesturedetector extends GetView {
  const IconGesturedetector({
    super.key,
    required this.assectName,
    required this.ontap,
    this.size = 24,
  });
  final Callback ontap;
  final String assectName;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ontap,
      child: Image.asset(assectName, height: size.w, width: size.w),
    );
  }
}

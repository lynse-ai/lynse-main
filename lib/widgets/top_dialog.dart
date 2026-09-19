import 'package:dting/utils/color_util.dart'; 
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TopDialog {
  TopDialog._();

  static void showTopSheet({required Widget child}) {
    showGeneralDialog(
      context: Get.context!,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: ColorUtil.fromHexString("#161616", 0.3),
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: child, //Material(color: Colors.white, child: child),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween(
            begin: Offset(0, -1),
            end: Offset(0, 0),
          ).animate(anim1),
          child: child,
        );
      },
    );
  }
}

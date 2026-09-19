import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'areement_controller.dart';

class AreementPage extends GetView<AreementController> {
  const AreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidgets.getAppBar(
        title: controller.title.value,
        textAlign: TextAlign.center,
      ),
      backgroundColor: ColorUtil.fromHexString("#FFFFFF"),
      body: SingleChildScrollView(
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.only(left: 24.w, right: 24.w, top: 8.w),
          child: Text(controller.text.value),
        ),
      ),
    );
  }
}

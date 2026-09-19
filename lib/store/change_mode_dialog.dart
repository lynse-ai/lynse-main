import 'package:dting/store/dting_store.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:dting/widgets/title_bottom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class ChangeModeDialog extends GetView<DtingStore> {
  const ChangeModeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    var clickAll = false.obs;
    return SafeArea(
      bottom: false,
      child: Container(
        margin: EdgeInsets.only(top: 50.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.w),
            topRight: Radius.circular(20.w),
          ),
          color: ColorUtil.fromHexString("#F2F4F7"),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TitleBottomWidget(title: "Tip"),

                  Text("changeModeTip".tr).descText(),
                  willNotShowAgain(clickAll),

                  BottomBarWidget(
                    title: "know",
                    color: Colors.black,
                    titleColor: Colors.white,
                    ontap: () {
                      print("clickAll:${clickAll.value}");
                      LocalDataBase().basicBox!.put(
                        "changeModeTip",
                        !clickAll.value,
                      );
                      Get.back();
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 34.w),
          ],
        ),
      ),
    );
  }

  Widget willNotShowAgain(RxBool clickAll) {
    return Obx(
      () => GestureDetector(
        onTap: () {
          clickAll.value = !clickAll.value;
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                clickAll.value
                    ? "assets/images_v3/select-redio.png"
                    : "assets/images_v3/redio.png",
                width: 20.w,
                height: 20.w,
              ),
              SizedBox(width: 6.w),
              Text("notShow".tr).descText(),
            ],
          ),
        ),
      ),
    );
  }
}

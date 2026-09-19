import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class EqotaWidget extends GetView {
  EqotaWidget({
    super.key,
    required this.ontap,
    required this.onClose,
    required this.point,
  });
  VoidCallback ontap;
  VoidCallback onClose;
  RxString point;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: Get.width,
      height: Get.height,
      decoration: BoxDecoration(color: ColorUtil.fromHexString("#161616", 0.5)),
      alignment: Alignment.center,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 50.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => Container(
                padding: EdgeInsets.only(top: 20.w, left: 16, right: 16.w),
                child: Column(
                  children: [
                    Text("eqotaTip2".tr).boldTitle(
                      fontSize: 17,
                      color: ColorUtil.fromHexString("#1D2129"),
                    ),
                    SizedBox(height: 12.w),
                    Text(
                      "eqotaPoint".trParams({'point': point.value}),
                    ).descText(fontSize: 15),
                    SizedBox(height: 12.w),
                  ],
                ),
              ),
            ),

            DividerWidget(spacer: 0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: Get.width,
                      height: 44.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                        ),
                        border: Border(
                          right: BorderSide(
                            color: ColorUtil.fromHexString("#E5E6EB"),
                            width: 1.w,
                          ),
                        ),
                      ),
                      child: Text("back".tr).descText(fontSize: 16),
                    ),
                  ),
                ),

                Expanded(
                  child: GestureDetector(
                    onTap: ontap,
                    child: Container(
                      width: Get.width,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        color: Colors.white,
                      ),
                      height: 44.w,
                      alignment: Alignment.center,
                      child: Text("Purchase".tr).descText(
                        fontSize: 16,
                        color: ColorUtil.fromHexString("#7857ED"),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

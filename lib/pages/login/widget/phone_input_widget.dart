import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class PhoneInputWidget extends StatelessWidget {
  const PhoneInputWidget({
    super.key,
    this.controller,
    this.onTap,
    this.keyboardType = TextInputType.number,
    this.hintText = 'phoneHint',
    this.inputFormatters,
    required this.error,
    this.focusNode,
  });

  final TextEditingController? controller;
  final GestureTapCallback? onTap;
  final TextInputType keyboardType;
  final String hintText;
  final Rx<bool> error;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        decoration: BoxDecoration(
          // color: ColorUtil.fromHexString('#FFFFFF'),
          // borderRadius: BorderRadius.circular(12.w),
          border: Border(
            bottom: BorderSide(
              color: ColorUtil.fromHexString(
                error.value ? "#FB4444" : "#B2B6BF",
              ),
              width: 1.w,
            ),
          ),
        ),
        width: Get.width,
        // height: 30.w,
        child: Row(
          children: [
            Row(
              children: [
                Text("+86").boldTitle(color: Colors.white),
                
                // Image.asset(
                //   "assets/images_v3/arrow-down.png",
                //   width: 22.w,
                //   height: 22.w,
                // ),
              ],
            ),
            Expanded(
              child: Container(
                width: Get.width,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.w),
                alignment: Alignment.center,
                // height: 30.w,
                child: TextField(
                  controller: controller,
                  onChanged: (value) {
                    if (value.isEmpty) {
                      error.value = true;
                    } else {
                      error.value = false;
                    }
                    print(error.value);
                  },
                  onTap: onTap,
                  readOnly: onTap != null ? true : false,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  focusNode: focusNode,
                  cursorColor: ColorUtil.fromHexString('#FFFFFF'),
                  style: TextStyle(
                    color: ColorUtil.fromHexString('#FFFFFF'),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText.tr,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: ColorUtil.fromHexString('#B2B6BF'),
                    ),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

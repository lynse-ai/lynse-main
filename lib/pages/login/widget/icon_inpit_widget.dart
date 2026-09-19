import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class IconInputWidget extends StatelessWidget {
  const IconInputWidget({
    super.key,
    this.controller,
    this.onTap,
    this.keyboardType = TextInputType.text,
    this.hintText = 'phoneHint',
    this.inputFormatters,
    required this.error,
  });

  final TextEditingController? controller;
  final GestureTapCallback? onTap;
  final TextInputType keyboardType;
  final String hintText;
  final Rx<bool> error;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    var tempShow = true.obs;
    return Obx(
      () => Container(
        padding: EdgeInsets.only(
          left: 16.w,
          top: 8.w,
          bottom: 8.w,
          right: 16.w,
        ),
        decoration: BoxDecoration(
          color: ColorUtil.fromHexString('#FFFFFF'),
          borderRadius: BorderRadius.circular(12.w),
          border:
              error.value
                  ? Border.all(
                    color: ColorUtil.fromHexString("#FB4444"),
                    width: 1.w,
                  )
                  : null,
          boxShadow: [
            BoxShadow(
              offset: Offset(0, 0),
              blurRadius: 20,
              spreadRadius: 0,
              color: ColorUtil.fromHexString("#D7D7D7", 0.35),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        width: 315.w,
        height: 40.w,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                obscureText: tempShow.value ? true : false,
                controller: controller,
                // onTap: onTap,
                onChanged: (value) {
                  if (value.isEmpty) {
                    error.value = true;
                  } else {
                    error.value = false;
                  }
                },
                readOnly: onTap != null ? true : false,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                cursorColor: ColorUtil.fromHexString('#333333'),
                style: TextStyle(
                  color: ColorUtil.fromHexString('#333333'),
                  fontSize: 16.w,
                  height: 20 / 16,
                ),
                decoration: InputDecoration(
                  hintText: hintText.tr,
                  hintStyle: TextStyle(
                    color: ColorUtil.fromHexString('#B2B6BF'),
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 0,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                tempShow.value = !tempShow.value;
              },
              child: SvgPicture.asset(
                tempShow.value
                    ? "assets/svg/sign/hide.svg"
                    : 'assets/svg/sign/display.svg',
                width: 20.w,
                height: 20.w,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

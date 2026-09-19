import 'dart:async';

import 'package:dting/model/verificationcode/verificationcode_sms_model.dart';
import 'package:dting/service/verificationcode_service.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_typedefs/rx_typedefs.dart';

class SendOtpWidget extends StatefulWidget {
  SendOtpWidget({
    super.key,
    required this.codeController,
    required this.phoneController,
    this.keyboardType = TextInputType.number,
    this.hintText = 'codeTip',
    this.inputFormatters,
    required this.sendType,
    required this.error,
    required this.phoneError,
    this.ontap,
    this.codeFocusNode,
    this.phoneFocusNode,
  });
  final TextEditingController codeController;
  final TextEditingController phoneController;
  final TextInputType keyboardType;
  final String hintText;
  final List<TextInputFormatter>? inputFormatters;
  final String sendType;
  final Rx<bool> error;
  final Rx<bool> phoneError;
  final Callback? ontap;
  final FocusNode? codeFocusNode;
  final FocusNode? phoneFocusNode;

  @override
  _SendOtpWidgetState createState() => _SendOtpWidgetState();
}

class _SendOtpWidgetState extends State<SendOtpWidget>
    with SingleTickerProviderStateMixin {
  int _seconds = 120; // 倒计时秒数
  Timer? _timer;
  bool send = true;

  DateTime? _endTime;

  // bool tempcolor = false; //显示error 文本框颜色
  void startTimer() {
    _endTime = DateTime.now().add(Duration(seconds: _seconds));

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _endTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        setState(() {
          _timer?.cancel();
          send = true;
          _seconds = 120; // 重置
        });
        print('倒计时结束');
      } else {
        setState(() {
          _seconds = remaining;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 避免内存泄漏
    super.dispose();
  }

  Future<void> sendOTP() async {
    var phone = widget.phoneController.text;
    var sendTypeString = widget.sendType;
    if (phone.isNotEmpty) {
      VerificationCodeBySMSModel sendSMS = VerificationCodeBySMSModel(
        phone: phone,
        actionType: sendTypeString,
      );
      var codeRes = await VerificationCodeService.getCodeBySMS(sendSMS);
      if (codeRes != null) {
        if (codeRes.code != 200) {
          var message = codeRes.msg;
          DialogHelper.showToastDialog(message);
        } else {
          setState(() {
            send = false;
            _seconds = 120;
            startTimer();
          });
          DialogHelper.showToastDialog("sendSuccess", duration: 1);
        }
      } else {
        DialogHelper.showToastDialog("endFail");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: ColorUtil.fromHexString(
                widget.error.value ? "#FB4444" : "#B2B6BF",
              ),
              width: 1.w,
            ),
          ),
        ),
        width: Get.width,
        padding: EdgeInsets.symmetric(vertical: 4.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: widget.codeController,
                onChanged: (value) {
                  setState(() {
                    if (value.isEmpty) {
                      widget.error.value = true;
                    } else {
                      widget.error.value = false;
                    }
                  });
                },
                onTap: widget.ontap,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                focusNode: widget.codeFocusNode,
                cursorColor: ColorUtil.fromHexString('#FFFFFF'),
                style: TextStyle(
                  color: ColorUtil.fromHexString('#FFFFFF'),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText.tr,
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
            SizedBox(width: 12.w),
            GestureDetector(
              onTap:
                  send
                      ? () {
                        if (widget.phoneController.text.isNotEmpty) {
                          if (widget.phoneFocusNode != null &&
                              widget.codeFocusNode != null &&
                              widget.codeFocusNode!.context != null &&
                              widget.codeFocusNode!.canRequestFocus &&
                              mounted) {
                            widget.phoneFocusNode!.unfocus();
                            FocusScope.of(
                              context,
                            ).requestFocus(widget.codeFocusNode);
                          }
                          sendOTP();
                        } else {
                          widget.phoneError.value = true;
                        }
                      }
                      : () {
                        print("倒计时中");
                      },
              child:
                  send
                      ? Text(
                        "getCode".tr,
                      ).boldTitle(color: ColorUtil.fromHexString("#B2B6BF"))
                      : Row(
                        children: [
                          Text("$_seconds").boldTitle(
                            color: ColorUtil.fromHexString("#FFFFFF"),
                          ),
                          Text("${"s".tr}${"Reacquisition".tr}").boldTitle(
                            color: ColorUtil.fromHexString("#B2B6BF"),
                          ),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

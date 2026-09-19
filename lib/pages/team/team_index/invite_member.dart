import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/bottom_bar.dart';
import 'package:dting/widgets/dialog/dialog.dart'; 
import 'package:dting/widgets/title_bottom.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; 
import 'package:get/get.dart';

class InviteMemberWidget extends StatefulWidget {
  InviteMemberWidget({super.key, required this.onClick});
  final Function(List<String> val) onClick;
  @override
  State<InviteMemberWidget> createState() => _InviteMemberWidgetState();
}

class _InviteMemberWidgetState extends State<InviteMemberWidget> {
  List<TextEditingController> controllerList = [TextEditingController()];
  var tag = false.obs;
  @override
  void dispose() {
    for (var c in controllerList) {
      c.dispose();
    }
    super.dispose();
  }

  void addPhoneField() {
    setState(() {
      controllerList.add(TextEditingController());
    });
  }

  void removePhoneField(int index) {
    if (controllerList.length > 1) {
      setState(() {
        controllerList.removeAt(index);
      });
    } else {
      // 如果只有一个，就清空而不删除
      controllerList[index].clear();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              child: TitleBottomWidget(title: "addTeamMember"),
            ),

            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              constraints: BoxConstraints(maxHeight: 200.w),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...controllerList.asMap().entries.map((entry) {
                      int index = entry.key;
                      TextEditingController controller = entry.value;
                      return _inputPhone(index: index, controller: controller);
                    }),
                  ],
                ),
              ),
            ),
            Obx(
              () => Container(
                padding: EdgeInsets.only(
                  right: 20.w,
                  left: 20.w,
                  bottom: 50.w,
                  top: 10.w,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: BottomBarWidget(
                        title: "cancel",
                        color: ColorUtil.fromHexString("#E7E9EC"),
                        titleColor: ColorUtil.fromHexString("#161616"),
                        ontap: () {
                          Get.back();
                        },
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: BottomBarWidget(
                        title: "submit",
                        color:
                            tag.value
                                ? null
                                : ColorUtil.fromHexString('#7E8492'),
                        ontap: () {
                          List<String> inviteePhoneList = [];
                          for (var phone in controllerList) {
                            if (phone.text.length != 11) {
                              DialogHelper.showToastDialog("confirmPhone");
                              return;
                            }
                            inviteePhoneList.add(phone.text);
                          }
                          if (inviteePhoneList.length == 1 &&
                              inviteePhoneList.first.trim().isEmpty) {
                            DialogHelper.showToastDialog("phoneHint");
                          } else {
                            widget.onClick(inviteePhoneList);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputPhone({
    required int index,
    required TextEditingController controller,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 15.w),
      alignment: Alignment.center,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.only(left: 16.w, top: 4.w, bottom: 4.w),
              decoration: BoxDecoration(
                color: ColorUtil.fromHexString('#FFFFFF'),
                borderRadius: BorderRadius.circular(10.w),
              ),
              clipBehavior: Clip.antiAlias,
              height: 40.w,
              child: Row(
                children: [
                  Row(
                    children: [
                      Text("+86").boldTitle(),
                      SizedBox(width: 12.w),
                      // Image.asset(
                      //   "assets/images_v3/arrow-down.png",
                      //   width: 22.w,
                      //   height: 22.w,
                      //   color: Colors.black,
                      // ),
                    ],
                  ),

                  Expanded(
                    child: TextField(
                      controller: controller,
                      inputFormatters: [LengthLimitingTextInputFormatter(11)],
                      keyboardType: TextInputType.number,
                      cursorColor: ColorUtil.fromHexString('#333333'),
                      style: TextStyle(
                        color: ColorUtil.fromHexString('#333333'),
                        fontSize: 14.w,
                        height: 22 / 14,
                      ),
                      onChanged: (phone) {
                        if (phone.length == 11) {
                          final regex = RegExp(r'^1[3-9]\d{9}$');
                          if (!regex.hasMatch(phone)) {
                            DialogHelper.showToastDialog("confirmPhone");
                          }
                        }
                        if (phone.trim().isNotEmpty) {
                          tag.value = true;
                        } else {
                          tag.value = false;
                        }
                      },

                      decoration: InputDecoration(
                        hintText: "phoneHint".tr,
                        hintStyle: TextStyle(
                          color: ColorUtil.fromHexString('#B2B6BF'),
                          fontSize: 14.w,
                          height: 22 / 14,
                        ),

                        isDense: true,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 0,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10.w),
          GestureDetector(
            onTap: () {
              if (index == controllerList.length - 1) {
                addPhoneField();
              } else {
                removePhoneField(index);
              }
            },
            child: Image.asset(
              index == controllerList.length - 1
                  ? 'assets/images_v3/team-search-member.png'
                  : 'assets/images_v3/team-remove-member.png',
              width: 20.w,
              height: 20.w,
            ),
          ),
        ],
      ),
    );
  }
}

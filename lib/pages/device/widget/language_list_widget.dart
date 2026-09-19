import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:dting/widgets/title_bottom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

enum SettingMode { global, fileTranslate }

class LanguageModel {
  String name;
  String code;
  String label;

  LanguageModel({required this.name, required this.code, required this.label});
}

class TransLangTitle extends TitleBottomWidget {
  TransLangTitle({super.key, required super.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          alignment: Alignment.center,
          height: 44.w,
          padding: EdgeInsets.only(top: 12.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.tr).boldTitle(fontSize: 16),
              GestureDetector(
                onTap: () {
                  Get.back();
                },
                child: Container(
                  width: 48.w,
                  height: 26.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4.w),
                    color: ColorUtil.fromHexString("#6750A4"),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "确定",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.w,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        DividerWidget(spacer: 10),
      ],
    );
  }
}

// ignore: must_be_immutable
class LanguageListWidget extends StatelessWidget {
  String title;
  String currentLanguageName;
  SettingMode settingMode;
  List<LanguageModel> languageList;
  double? maxHeight;

  LanguageListWidget({
    super.key,
    required this.title,
    required this.currentLanguageName,
    required this.settingMode,
    required this.languageList,
    this.maxHeight,
  });

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  settingMode == SettingMode.global
                      ? TitleBottomWidget(title: title)
                      : TransLangTitle(title: title),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white,
                    ),
                    height: maxHeight,
                    child: ListView.builder(
                      shrinkWrap: maxHeight == null,
                      physics:
                          maxHeight != null
                              ? const ClampingScrollPhysics()
                              : NeverScrollableScrollPhysics(),
                      itemCount: languageList.length,
                      itemBuilder: (context, index) {
                        final language = languageList[index];
                        final isSelect = language.name == currentLanguageName;
                        final isLast = index == languageList.length - 1;

                        return _languageItemWidget(
                          title: language.label.tr,
                          isSelect: isSelect,
                          isLast: isLast,
                          onTap: () {
                            Get.back(result: language);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageItemWidget({
    required String title,
    required bool isSelect,
    required bool isLast,
    Function()? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.w),
        decoration: BoxDecoration(
          border:
              isLast
                  ? null
                  : Border(
                    bottom: BorderSide(
                      color: ColorUtil.fromHexString("#F2F4F7"),
                    ),
                  ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color:
                    isSelect
                        ? Colors.black
                        : ColorUtil.fromHexString("#7E8492"),
                fontWeight: FontWeight.w500,
                fontSize: 12.w,
                height: 22 / 12,
              ),
            ),
            isSelect
                ? Container(
                  width: 48.w,
                  height: 26.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4.w),
                    color: ColorUtil.fromHexString("#6750A4"),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "已选",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.w,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
                : Container(
                  width: 48.w,
                  height: 26.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4.w),
                    border: Border.all(
                      color: ColorUtil.fromHexString("#D0D5DD"),
                    ),
                    color: Colors.white,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "选择",
                    style: TextStyle(
                      color: ColorUtil.fromHexString("#344054"),
                      fontSize: 10.w,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

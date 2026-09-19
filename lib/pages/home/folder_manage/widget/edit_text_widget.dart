import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/bottom_botton.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/divider_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class EditTextWidget extends StatefulWidget {
  EditTextWidget({
    Key? key,
    required this.onClick,
    required this.needEditText,
    required this.title,
    this.cancelText = "cancel",
    this.okText = "save",
    this.marginSize = 20,
    this.hintText,
    this.isEditSpeackName = false,
  }) : super(key: key);

  final String needEditText;
  final String okText;
  final String title;
  final String cancelText;
  final String? hintText;
  final Function(bool? val, String editText) onClick;
  final bool isEditSpeackName;
  final double marginSize;

  @override
  _EditTextWidgetState createState() => _EditTextWidgetState();
}

class _EditTextWidgetState extends State<EditTextWidget> {
  late TextEditingController _reNameController;
  late FocusNode _focusNode;
  var clickAll = true.obs;

  bool isRunClickHandler = false;
  @override
  void initState() {
    super.initState();
    _reNameController = TextEditingController(text: widget.needEditText);
    _focusNode = FocusNode();

    // 延迟一小段时间后请求焦点（确保Widget已渲染）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNode.canRequestFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _reNameController.dispose();
    _focusNode.dispose();
    super.dispose();
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
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title.tr).boldTitle(fontSize: 16),
                GestureDetector(
                  onTap: () {
                    Get.back();
                  },
                  child: Image.asset(
                    "assets/images_v3/edit-cancel.png",
                    width: 23.w,
                    height: 23.w,
                  ),
                ),
              ],
            ),
            DividerWidget(spacer: 12),
            SizedBox(height: 10.w),

            /// 滚动内容区
            _reNameVoiceFileName(),
            SizedBox(height: 40.w),
          ],
        ),
      ),
    );
  }

  Widget editAllName() {
    return Obx(
      () => GestureDetector(
        onTap: () {
          clickAll.value = !clickAll.value;
        },
        child: Container(
          padding: EdgeInsets.only(top: 10.w),
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
              Flexible(
                child: Text(
                  '${"all".tr} “${widget.needEditText}',
                ).descText(maxLine: null, overflow: TextOverflow.ellipsis),
              ),
              Text("”${"editName".tr}").descText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reNameVoiceFileName() {
    var color = "#7E8492".obs;
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.w),
              color: ColorUtil.fromHexString("#F8F8F8"),
            ),
            child: TextField(
              controller: _reNameController,
              focusNode: _focusNode, // 添加焦点节点
              autofocus: true, // 自动获取焦点
              maxLines: null,
              // inputFormatters: [OnlyLetterNumberFormatter()],
              cursorColor: ColorUtil.fromHexString('#333333'),
              style: TextStyle(
                color: ColorUtil.fromHexString('#333333'),
                fontSize: 16.w,
                height: 20 / 16,
              ),
              onChanged: (value) {
                if (value.trim().isEmpty) {
                  color.value = "#7E8492";
                } else {
                  color.value = "#7857ED";
                }
              },
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 0,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          widget.hintText != null
              ? Text(widget.hintText!).descText(
                fontSize: 10,
                height: 1.4,
                color: ColorUtil.fromHexString("#161616", 0.5),
              )
              : SizedBox.shrink(),
          widget.isEditSpeackName ? editAllName() : SizedBox(),
          SizedBox(height: 20.w),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: BottomBottonWidget(
                  text: widget.cancelText.tr,
                  margin: 0,
                  backgroundColor: ColorUtil.fromHexString("#E7E9EC"),
                  textColor: ColorUtil.fromHexString("#161616"),
                  ontap: () {
                    Get.back();
                  },
                ),
              ),
              SizedBox(width: 20.w),
              Expanded(
                child: BottomBottonWidget(
                  text: widget.okText.tr,
                  margin: 0,
                  backgroundColor: ColorUtil.fromHexString(color.value),
                  ontap: () {
                    if (isRunClickHandler) return;
                    isRunClickHandler = true;
                    if (_reNameController.text.trim().isEmpty == true) {
                      DialogHelper.showToastDialog("cannotEmpty");
                    } else {
                      if (widget.isEditSpeackName) {
                        widget.onClick(clickAll.value, _reNameController.text);
                      } else {
                        widget.onClick(true, _reNameController.text);
                      }
                    }
                    Future.delayed(Duration(seconds: 1), () {
                      isRunClickHandler = false;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:dting/model/file_model/folder_management_model/folder_model.dart';
import 'package:dting/pages/home/folder_manage/folder_manage_controller.dart';
import 'package:dting/pages/home/folder_manage/widget/create_folder_widget.dart';
import 'package:dting/pages/home/folder_manage/widget/edit_text_widget.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

class FolderManagePage extends GetView<SideBarController> {
  const FolderManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarWidgets.getAppBar(
        title: "folderManage".tr,
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
        actions: [
          GestureDetector(
            onTap: () {
              controller.handleEditTap();
            },
            child: Obx(
              () => Text(
                controller.isEdit.value ? "edit-save".tr : "edit-normal".tr,
                style: TextStyle(
                  color: Theme.of(context).primaryColor.withOpacity(0.8),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      body: Container(
        alignment: Alignment.topCenter,
        padding: EdgeInsets.only(left: 24.w, right: 24.w, bottom: 34.w),
        child: Column(
          children: [
            // 固定文件夹（不可滚动部分）
            _defaltFolderItem(
              folderName: "allFile".tr,
              folderId: "-1",
              assectname: 'assets/images_v3/allFile.png',
            ),
            _defaltFolderItem(
              folderName: "notAI".tr,
              folderId: "-2",
              assectname: 'assets/images_v3/notTrans.png',
            ),
            _defaltFolderItem(
              folderName: "notRead".tr,
              folderId: "-3",
              assectname: 'assets/images_v3/notRead.png',
            ),

            // 拖拽列表（可滚动部分）
            Expanded(
              child: Obx(() {
                if (controller.isEdit.value) {
                  return ReorderableListView(
                    onReorder: controller.reorder,
                    children:
                        controller.folderList
                            .map(
                              (folder) => Container(
                                key: ValueKey(folder.id),
                                height: 50.w,
                                margin: EdgeInsets.only(top: 10.w),
                                child: FolderItemWidget(folder: folder),
                              ),
                            )
                            .toList(),
                  );
                } else {
                  return ListView(
                    children:
                        controller.folderList
                            .map(
                              (folder) => Container(
                                key: ValueKey(folder.id),
                                height: 50.w,
                                margin: EdgeInsets.only(top: 10.w),
                                child: FolderItemWidget(folder: folder),
                              ),
                            )
                            .toList(),
                  );
                }
              }),
            ),

            // 底部按钮（固定部分）
            GestureDetector(
              onTap: () {
                Get.bottomSheet(CreateFolderWidget(), isScrollControlled: true);
              },
              child: Container(
                height: 50.w,
                margin: EdgeInsets.only(top: 10.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images_v3/addFolder.png',
                      width: 12.w,
                      height: 12.w,
                    ),
                    SizedBox(width: 10.w),
                    Text("createFolder".tr).descText(fontSize: 12),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10.w),
            Text(
              "folderChangeIndex".tr,
            ).descText(fontSize: 12, color: ColorUtil.fromHexString("#B2B6BF")),
          ],
        ),
      ),
    );
  }

  Widget _defaltFolderItem({
    required String folderName,
    required String folderId,
    required String assectname,
  }) {
    return Container(
      height: 50.w,
      margin: EdgeInsets.only(top: 10.w),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 15.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: ColorUtil.fromHexString("#FFFFFF"),
      ),
      child: Row(
        children: [
          Image.asset(assectname, width: 20.w, height: 20.w),
          SizedBox(width: 4.w),
          Text(folderName.tr).descText(),
        ],
      ),
    );
  }
}

class FolderItemWidget extends StatefulWidget {
  FolderItemWidget({
    super.key,
    required this.folder,
    // required this.slidableController,
  });
  late FolderInfo folder;
  @override
  _FolderItemWidgetState createState() => _FolderItemWidgetState();
}

class _FolderItemWidgetState extends State<FolderItemWidget>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  var thisController = Get.find<SideBarController>();

  late SlidableController slidableController;
  @override
  void initState() {
    super.initState();
    slidableController = SlidableController(this);
    thisController.slibableControllers[widget.folder.id] = slidableController;
  }

  @override
  void dispose() {
    super.dispose();
    thisController.slibableControllers.remove(widget.folder.id);
    slidableController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Container(
          height: 50.w,
          width: Get.width,
          decoration: BoxDecoration(
            color: ColorUtil.fromHexString("#FF4671"),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        Slidable(
          controller: slidableController,
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: 0.28,
            children: [
              Flexible(
                child: Container(
                  height: 50.w,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12.w),
                      bottomRight: Radius.circular(12.w),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      GestureDetector(
                        onTap: () {
                          slidableController.close();
                          Get.bottomSheet(
                            EditTextWidget(
                              needEditText: widget.folder.folderName ?? "",
                              title: "editFolderName",
                              onClick: (bool? val, String editText) async {
                                if (val != null && val) {
                                  thisController.editFolderName(
                                    editName: editText,
                                    folderId: widget.folder.id,
                                  );
                                }
                              },
                            ),
                            isScrollControlled: true,
                          );
                          print("修改文件夹名称");
                        },
                        child: Container(
                          padding: EdgeInsets.all(8.w),
                          child: Image.asset(
                            "assets/assets/folder-edit.png",
                            width: 20.w,
                            height: 20.w,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 10.w),
                        height: Get.height,
                        width: 1.w,
                        color: Colors.white,
                      ),
                      GestureDetector(
                        onTap: () {
                          slidableController.close();
                          DialogHelper.showDialogByChild(
                            title: 'delete',
                            cancelText: "cancel",
                            child: Text(
                              'deleteFolder'.tr,
                              textAlign: TextAlign.center,
                            ),
                            okOntap: () {
                              thisController.deleteFolder(widget.folder.id);
                              Get.back();
                            },
                          );
                          print("删除文件夹");
                        },
                        child: Container(
                          padding: EdgeInsets.all(8.w),
                          child: Image.asset(
                            "assets/assets/folder-delete.png",
                            width: 20.w,
                            height: 20.w,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          child: Container(
            height: 50.w,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 15.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: ColorUtil.fromHexString("#FFFFFF"),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/images_v3/folder.png',
                  width: 20.w,
                  height: 20.w,
                ),
                SizedBox(width: 4.w),
                Text(widget.folder.folderName ?? "").descText(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}

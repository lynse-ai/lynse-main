import 'package:dting/pages/device/prompt/prompt_list_controller.dart';
import 'package:dting/router/modules/translate_router.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_layout_grid/flutter_layout_grid.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class PromptListPage extends GetView<PromptListController> {
  const PromptListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      appBar: AppBarWidgets.getAppBar(
        title: "选择总结模版",
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#FFFFFF"),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Column(
            children: [
              // 分类标签横向布局
              SizedBox(
                height: 52.w,
                child: Container(
                  color: ColorUtil.fromHexString("#FFFFFF"),
                  padding: EdgeInsets.fromLTRB(16.w, 8.w, 16.w, 8.w),
                  child: Obx(() {
                    // 必须使用可观察变量
                    final categoryValue = controller.selectCategory.value;

                    // 先检查数据是否已加载
                    if (controller.promptGroupList.isEmpty) {
                      return Container(); // 如果分类列表为空，显示空容器
                    }

                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.categoryList.length,
                      separatorBuilder:
                          (context, index) => SizedBox(width: 16.w),
                      itemBuilder: (context, index) {
                        final isSelected =
                            controller.categoryList[index] == categoryValue;
                        return GestureDetector(
                          onTap: () {
                            // 切换分类
                            controller.selectCategory.value =
                                controller.categoryList[index];
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 6.w,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color:
                                    isSelected
                                        ? Colors.transparent
                                        : ColorUtil.fromHexString("#7E8492"),
                              ),
                              color:
                                  isSelected
                                      ? ColorUtil.fromHexString("#7857ED")
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(12.w),
                            ),
                            child: Text(
                              controller.categoryList[index],
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? Colors.white
                                        : ColorUtil.fromHexString("#666666"),
                                fontSize: 14.w,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
              SizedBox(height: 16.w),
              // 瀑布流布局
              Expanded(
                child: Obx(() {
                  // 使用可观察变量
                  final templateIdValue = controller.selectTemplateId.value;

                  // 当模板列表为空时显示加载状态或空提示
                  if (controller.templateList.isEmpty) {
                    return Center(
                      child:
                          controller.promptGroupList.isEmpty
                              ? CircularProgressIndicator()
                              : Text("该分类下暂无模板"),
                    );
                  }

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: LayoutGrid(
                      // 定义列：两列，等宽（1.fr）
                      columnSizes: [1.fr, 1.fr],
                      // 定义行：行高由内容决定（auto），重复模式
                      rowSizes: List.generate(
                        (controller.templateList.length / 2).ceil(), // 计算所需行数
                        (index) => auto, // 每一行都自适应高度
                      ),
                      // 行列间距
                      rowGap: 12.w, // 替代 mainAxisSpacing
                      columnGap: 12.w, // 替代 crossAxisSpacing
                      children: [
                        for (
                          int index = 0;
                          index < controller.templateList.length;
                          index++
                        )
                          PromptCard(
                            title: controller.templateList[index].name ?? '',
                            description:
                                controller.templateList[index].category ?? '',
                            tags: controller.templateList[index].tags ?? [],
                            isSelected:
                                controller.templateList[index].id ==
                                templateIdValue,
                            onTap: () {
                              // 选择卡片
                              if (controller.templateList[index].id != null) {
                                controller.selectTemplateId.value =
                                    controller.templateList[index].id!;
                              }
                            },
                            index: index,
                          ),
                      ],
                    ),
                  );
                }),
              ),

              SizedBox(height: 86.w), // 底部空间，确保内容不被底部按钮遮挡
            ],
          ),
          // 底部悬停按钮
          Positioned(
            bottom: 24.w,
            left: 16.w,
            right: 16.w,
            child: GestureDetector(
              onTap: () {
                // 应用选中的模板
                controller.applySelectedTemplate();
              },
              child: Container(
                height: 52.w,
                decoration: BoxDecoration(
                  color: ColorUtil.fromHexString("#7857ED"),
                  borderRadius: BorderRadius.circular(26.w),
                ),

                alignment: Alignment.center,
                child: Text(
                  "应用",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.w,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 提示卡片组件
class PromptCard extends StatelessWidget {
  const PromptCard({
    super.key,
    required this.title,
    required this.description,
    required this.tags,
    required this.isSelected,
    required this.onTap,
    required this.index,
  });

  final String title;
  final String description;
  final List<String> tags;
  final bool isSelected;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.w),
          border:
              isSelected
                  ? Border.all(
                    color: ColorUtil.fromHexString("#7857ED"),
                    width: 2.w,
                  )
                  : Border.all(color: Colors.transparent, width: 2.w),
        ),
        child: Stack(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题和下拉箭头
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title).mainTitle(fontSize: 16),

                      GestureDetector(
                        onTap: () {
                          onTap();
                          Get.toNamed(
                            TranslateRouter.promptPreviewPage,
                            arguments: {'templateIndex': index},
                          );
                        },
                        child: Image.asset(
                          'assets/images/device/preview.png',
                          width: 23.w,
                          height: 23.w,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.w),
                  // 描述标签
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.w,
                    children:
                        tags.map((tag) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.w,
                            ),
                            decoration: BoxDecoration(
                              color: ColorUtil.fromHexString("#F2F4F7"),
                              borderRadius: BorderRadius.circular(4.w),
                            ),
                            child: Text(tag).descText(fontSize: 12),
                          );
                        }).toList(),
                  ),
                  SizedBox(height: 8.w),
                  // 大模型logo
                  Row(
                    children: [
                      Image.asset(
                        'assets/images_v3/desktop.png',
                        width: 18.w,
                        height: 18.w,
                      ),
                      SizedBox(width: 4.w),
                      Text("Dting"),
                    ],
                  ),
                ],
              ),
            ),

            if (isSelected)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  height: 28.w,
                  width: 28.w,
                  decoration: BoxDecoration(
                    color: ColorUtil.fromHexString("#7857ED"),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12.w),
                      bottomRight: Radius.circular(10.w),
                    ),
                  ),
                  child: Icon(
                    Icons.check_sharp,
                    color: Colors.white,
                    size: 20.w,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:dting/model/translate/prompt_template_model.dart';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:dting/pages/device/prompt/prompt_preview_controller.dart';

class PromptPreviewPage extends GetView<PromptPreviewController> {
  const PromptPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      // 顶部AppBar
      appBar: AppBarWidgets.getAppBar(
        title: '总结模板',
        showBackButton: true,
        textAlign: TextAlign.center,
        backgroundColor: ColorUtil.fromHexString("#F2F4F7"),
      ),

      // 主内容区域
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // PageView 主体内容
          LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: EdgeInsets.only(
                  top: 16.w,
                  left: 6.w,
                  right: 6.w,
                  bottom: 88.w,
                ), // 为底部按钮留出空间
                child: SizedBox(
                  height: constraints.maxHeight - 92.w, // 限制高度
                  child: Builder(
                    builder: (context) {
                      // 在构建后设置初始页面
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (controller.currentPageIndex.value > 0 &&
                            controller.currentPageIndex.value <
                                controller.templateList.length) {
                          controller.pageController.jumpToPage(
                            controller.currentPageIndex.value,
                          );
                        }
                      });
                      return PageView.builder(
                        controller: controller.pageController,
                        itemCount: controller.templateList.length,
                        onPageChanged: controller.onPageChanged,
                        itemBuilder: (context, index) {
                          return AnimatedBuilder(
                            animation: controller.pageController,
                            builder: (context, child) {
                              double value = 1.0;
                              if (controller
                                  .pageController
                                  .position
                                  .haveDimensions) {
                                // 计算当前页面和视口中心的距离
                                value =
                                    (controller.pageController.page! - index)
                                        .abs();
                                // 当页面在视口中时，缩放值为1.0，离开视口时逐渐缩小
                                value = 1.0 - (value * 0.15).clamp(0.0, 1.0);
                              }

                              return Transform.scale(
                                scale: value,
                                child: child,
                              );
                            },
                            child: SummaryTemplateCard(
                              template: controller.templateList[index],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // 底部悬浮应用按钮
          Positioned(
            bottom: 24.w,
            left: 16.w,
            right: 16.w,
            child: GestureDetector(
              onTap: controller.applyTemplate,
              child: Container(
                height: 52.w,
                decoration: BoxDecoration(
                  color: ColorUtil.fromHexString('#7857ED'),
                  borderRadius: BorderRadius.circular(26.w),
                ),
                alignment: Alignment.center,
                child: Text('应用').mainTitle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 总结模板卡片组件
class SummaryTemplateCard extends StatelessWidget {
  const SummaryTemplateCard({super.key, required this.template});

  final PromptTemplateModel template;

  @override
  Widget build(BuildContext context) {
    // 计算卡片最大高度，确保不遮挡底部按钮
    final screenHeight = MediaQuery.of(context).size.height;
    final cardMaxHeight = screenHeight - 552.w; // 减去顶部导航栏和底部按钮高度

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8.w,
            offset: Offset(0, 2.w),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: cardMaxHeight),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(template.name!).boldTitle(
                    fontSize: 18,
                    color: ColorUtil.fromHexString('#333333'),
                  ),
                ],
              ),

              SizedBox(height: 10.w),
              Divider(height: 1.w, color: ColorUtil.fromHexString('#CED1D8')),
              SizedBox(height: 12.w),
              // 标签列表
              if (template.tags != null && template.tags!.isNotEmpty)
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.w,
                  children:
                      template.tags!.map((tag) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 4.w,
                          ),
                          decoration: BoxDecoration(
                            color: ColorUtil.fromHexString('#F5F5F5'),
                            borderRadius: BorderRadius.circular(6.w),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 12.w,
                              color: ColorUtil.fromHexString('#666666'),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              SizedBox(height: 18.w),
              MarkdownBody(
                data: template.content ?? '',
                styleSheet: MarkdownStyleSheet(
                  h1: TextStyle(
                    fontSize: 16.8,
                    fontWeight: FontWeight.bold,
                    color: ColorUtil.fromHexString('#000000'),
                  ),
                  h2: TextStyle(
                    fontSize: 16.8,
                    fontWeight: FontWeight.bold,
                    color: ColorUtil.fromHexString('#000000'),
                  ),
                  p: TextStyle(
                    fontSize: 14.w,
                    color: ColorUtil.fromHexString("#1E1E1E"),
                    height: 21 / 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:dting/styles/common.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/widgets/slider_indicator_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import 'bootstrapoperation_controller.dart';

class BootstrapOperationPage extends GetView<BootstrapOperationController> {
  const BootstrapOperationPage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(BootstrapOperationController());
    return SizedBox(
      height: 512.w,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Container(
          height: Get.height,
          alignment: Alignment.topCenter,
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          decoration: BoxDecoration(
            color: ColorUtil.fromHexString("#FFFFFF"),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.w),
              topRight: Radius.circular(16.w),
            ),
            gradient: LinearGradient(
              colors: [
                ColorUtil.fromHexString("#FFFFFF"),
                ColorUtil.fromHexString("#D5D9E2"),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SliderIndicatorBar(),
                  Text("searching".tr).mainTitle(fontSize: 18),
                  SizedBox(height: 8.w),

                  FadeCarouselSlider(
                    interval: Duration(seconds: 4),
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text("seatchTip1".tr).descText(
                            color: ColorUtil.fromHexString("#5B5E68"),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 20.w),
                          Stack(
                            children: [
                              Image.asset(
                                "assets/images_v3/search-device2.png",
                                height: 98.w,
                                width: 250.w,
                              ),
                              Positioned(
                                right: 32,
                                top: 22,
                                child: Image.asset(
                                  'assets/images_v3/search-guidelines.png',
                                  height: 52.w,
                                  fit: BoxFit.fitHeight,
                                ),
                              ),
                              Positioned(
                                right: 25,
                                top: 0,
                                child: Lottie.asset(
                                  'assets/lotties/search.lottie',
                                  width: 62.w,
                                  fit: BoxFit.fitWidth,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text("seatchTip2".tr).descText(
                            color: ColorUtil.fromHexString("#5B5E68"),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 20.w),
                          Image.asset(
                            "assets/images_v3/search-device3.png",
                            height: 98.w,
                            width: 250.w,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Lottie.asset('assets/lotties/Newaction.lottie', width: Get.width),
            ],
          ),
        ),
      ),
    );
  }
}

class FadeCarouselSlider extends StatefulWidget {
  final List<Widget> children;
  final Duration interval;
  final Duration fadeDuration;
  final bool autoPlay;

  const FadeCarouselSlider({
    super.key,
    required this.children,
    this.interval = const Duration(seconds: 3),
    this.fadeDuration = const Duration(milliseconds: 500),
    this.autoPlay = true,
  });

  @override
  State<FadeCarouselSlider> createState() => _FadeCarouselSliderState();
}

class _FadeCarouselSliderState extends State<FadeCarouselSlider>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoPlay) {
      _startAutoPlay();
    }
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(widget.interval, (_) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.children.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSize(
          duration: Duration(seconds: 3),
          curve: Curves.easeInOut,
          child: AnimatedSwitcher(
            duration: widget.fadeDuration,
            transitionBuilder:
                (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
            child: Container(
              key: ValueKey(_currentIndex),
              child: widget.children[_currentIndex],
            ),
          ),
        ),
      ],
    );
  }
}

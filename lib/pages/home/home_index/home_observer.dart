import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart'; 

class HomeRouteObserver extends GetObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    print('新页面已打开: ${route.settings.name}');
    // if(route.settings.name)
    if (Get.isRegistered<HomeIndexController>()) {
      // Get.find<HomeIndexController>().closeSlidable();
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    print('页面已关闭: ${route.settings.name}');
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);
    print('页面被强制移除: ${route.settings.name}');
  }
}

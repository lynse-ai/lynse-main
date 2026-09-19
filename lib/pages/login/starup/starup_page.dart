import 'package:dting/pages/login/widget/logo_widget.dart';
import 'package:dting/utils/color_util.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'starup_controller.dart';

class StarupPage extends GetView<StarupController> {
  const StarupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ColorUtil.fromHexString("#161616", 0),
            ColorUtil.fromHexString("#161616"),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        image: DecorationImage(
          image: AssetImage('assets/images_v3/login-bg.png'),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Scaffold(body: Center(child: LogoWidget())),
      ),
    );
  }
}

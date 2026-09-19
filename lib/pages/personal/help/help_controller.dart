import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpAndFeedBackController extends GetxController {
  @override
  void onInit() {
    super.onInit();
  }

  Future<void> callPhone() async {
    final Uri url = Uri(scheme: 'tel', path: "13632872577");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw '无法拨打电话 ${13632872577}';
    }
  }

  Future<void> copyPhone() async {
    Clipboard.setData(ClipboardData(text: "13632872577"));
    DialogHelper.showToastDialog("copySuccess");
  }
}

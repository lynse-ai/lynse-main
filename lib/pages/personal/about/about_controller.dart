import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutController extends GetxController {
  var versionString = "".obs;
  @override
  void onInit() {
    super.onInit();
    getVersion();
  }

  Future<void> getVersion() async {
    final info = await PackageInfo.fromPlatform();
    versionString.value = info.version;
  }
}

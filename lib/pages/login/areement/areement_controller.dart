import 'package:get/get.dart';

class AreementController extends GetxController {
  var text = "".obs;
  var title = "".obs;
  @override
  void onInit() {
    // TODO: implement onInit
    super.onInit();
    title.value = (Get.arguments['title']);
    text.value = (Get.arguments['text']);
  }
}

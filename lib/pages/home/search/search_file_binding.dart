import 'package:dting/pages/home/search/search_file_controller.dart';
import 'package:get/get.dart';

class SearchBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SearchFileController>(() => SearchFileController());
  }
}

import 'package:dting/pages/device/prompt/prompt_list_binding.dart';
import 'package:dting/pages/device/prompt/prompt_list_page.dart';
import 'package:dting/pages/device/prompt/prompt_preview_binding.dart';
import 'package:dting/pages/device/prompt/prompt_preview_page.dart';
import 'package:get/get.dart';

class TranslateRouter {
  static const String promptListPage = "/promptListPage";
  static const String promptPreviewPage = "/promptPreviewPage";

  static final pages = [
    GetPage(
      name: promptListPage,
      page: () => const PromptListPage(),
      binding: PromptListBinding(),
    ),
    GetPage(
      name: promptPreviewPage,
      page: () => const PromptPreviewPage(),
      binding: PromptPreviewBinding(),
    ),
  ];
}

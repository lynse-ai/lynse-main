import 'package:dting/pages/device/menu/concel/concel_controller.dart';
import 'package:dting/pages/device/voice_details/voicedetails_controller.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/store/dting_store.dart';
import 'package:get/get.dart' hide Node;

class MindController extends GetxController {
  var appController = Get.find<DtingStore>();
  var detailController = Get.find<VoiceDetailsController>();
  var teamFileController = Get.find<TeamFileController>();
  var homeController = Get.find<HomeIndexController>();
  var concelController = Get.find<ConcelController>();

  bool get isNotEmpty =>
      appController.selectFileInfo.value.transcribeTaskId != null &&
      detailController.conclData.value.conclusionText != null &&
      detailController.conclData.value.conclusionText != "";

  @override
  Future<void> onInit() async {
    super.onInit();
  }

  @override
  void onClose() {
    Get.delete<MindController>();
    // print("退出MindController");
    super.onClose();
  }

  // WebViewController webViewController =
  //     WebViewController()
  //       ..setJavaScriptMode(JavaScriptMode.unrestricted)
  //       ..setBackgroundColor(ColorUtil.fromHexString("#FFFFFF"))
  //       ..setNavigationDelegate(
  //         NavigationDelegate(
  //           onPageFinished: (String url) {
  //             print("WebView Page finished loaded: $url");
  //           },
  //           onWebResourceError: (WebResourceError error) {
  //             print(
  //               "WebView Page error: ${error.errorCode} ${error.description}",
  //             );
  //           },
  //         ),
  //       )
  //       ..addJavaScriptChannel(
  //         'WebViewBridge',
  //         onMessageReceived: (JavaScriptMessage message) {
  //           print("WebView message: ${message.message}");
  //         },
  //       );

  // void initWebview(String mindString) async {
  //   String htmlString = '''
  //     <!DOCTYPE html>
  //     <html>
  //     <head>
  //       <title>Mindmap</title>
  //       <style>
  //       .markmap {
  //         position: relative;
  //         height:100vh;
  //         width: 100%;
  //         background-color:#fff;
  //       }

  //       svg.markmap {
  //         width: 100%;
  //         height: 100vh;
  //       }
  //       </style>
  //       <!-- 引入插件 -->
  //       <script src="https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js"></script>

  //       <!-- 引入markmap.js -->
  //       <script src="https://cdn.jsdelivr.net/npm/markmap-autoloader@latest"></script>
  //     </head>
  //     <body>
  //       <div style="display:none;" id="base64Container"></div>

  //       <!-- markdown mindmap容器 -->
  //       <div class="markmap" id="markmap">
  //         <!-- markdown数据内容 -->
  //         <script type="text/template">
  //           $mindString
  //         </script>
  //       </div>
  //     </body>
  //     </html>
  //   ''';

  //   webViewController.loadHtmlString(htmlString);
  // }

  // Future<String> exportImage({type = 'png'}) async {
  //   // print('exportImage call in...');
  //   try {
  //     String buildImgScript = '''
  //       try {
  //         const _svg = document.querySelector('#markmap');
  //         html2canvas(_svg).then((canvas) => {
  //           const svgData = canvas.toDataURL('image/png');
  //           document.getElementById('base64Container').innerText = svgData;
  //         });
  //       } catch (error) {
  //         console.error('SVG转换为图片失败, ' + error);
  //       };
  //     ''';

  //     await webViewController.runJavaScript(buildImgScript);

  //     await Future.delayed(const Duration(seconds: 1));
  //     String imgData =
  //         await webViewController.runJavaScriptReturningResult(
  //               '''document.getElementById('base64Container').innerText''',
  //             )
  //             as String;
  //     // print('===controller imgData: $imgData');
  //     return imgData.split('base64,').last;
  //   } catch (e) {
  //     print('Error exporting image: $e');
  //     return '';
  //   }
  // }
}

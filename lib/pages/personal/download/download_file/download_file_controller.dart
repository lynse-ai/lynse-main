import 'dart:io';

import 'package:dting/store/dting_store.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';

class DownloadFileController extends GetxController {
  var appController = Get.find<DtingStore>();
  var files = <String>[].obs;
  var folderPath = "".obs;
  @override
  void onInit() {
    super.onInit();
    folderPath.value = Get.arguments['folder'];
    switchFileOrFolder(folderPath.value);
  }

  switchFileOrFolder(String path) {
    files.value = [];
    Directory downloadDirectory = Directory(path);
    if (downloadDirectory.existsSync()) {
      List<FileSystemEntity> allFiles = downloadDirectory.listSync();
      for (var file in allFiles) {
        final entity = FileSystemEntity.typeSync(file.path);
        switch (entity) {
          case FileSystemEntityType.file:
            print("这是一个文件:${file.path}");
            files.add(file.path);
            break;
          case FileSystemEntityType.directory:
            print("这是一个文件夹:${file.path}");
            break;
          case FileSystemEntityType.notFound:
            print("路径不存在");
            break;
          default:
            print("未知类型");
        }
      }
    }
  }

  void openFile(String file) async {
    final result = await OpenFile.open(file);
    print("打开结果: ${result.message}");
  }

  String showName(String path) {
    return path.split("/").last;
  }

  void deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
        print("文件已删除: $path");
      } catch (e) {
        print("删除失败: $e");
      }
    } else {
      print("文件不存在: $path");
    }
  }
}

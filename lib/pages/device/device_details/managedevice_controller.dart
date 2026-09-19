import 'dart:io';

import 'package:dting/even_bus.dart';
import 'package:dting/model/device_model/deviceinfo_model.dart';
import 'package:dting/model/ota/ota_firmware_model.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';
import 'package:dting/service/device_service.dart';
import 'package:dting/service/file_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:version/version.dart';
import 'package:dting/model/ota/ota_version_model.dart';
import 'package:dting/http/http_helper.dart';
import 'package:dting/model/baseapi/response_api_model.dart';
// 引入日志库
import 'package:logging/logging.dart';

class ManageDeviceController extends GetxController {
  // 创建日志记录器
  final Logger _logger = Logger('ManageDeviceController');
  var appController = Get.find<DtingStore>();

  var selectDevice = DeviceInfoModel().obs;

  @override
  void onInit() {
    super.onInit();
    selectDevice.value = (Get.arguments['selectDevice']);

    // 设备蓝牙连接成功后，获取设备的信息
    eventBus.on<BluetoothConnectedEvent>().listen((event) async {
      EasyLoading.show(status: '蓝牙已连接，正在读取设备信息...');
      selectDevice.value = appController.connectingDevice.value;
      // 刷新设备信息
      await NvEasyPlugin().getBattery();
      await NvEasyPlugin().querySN();
      await NvEasyPlugin().queryVersion();
      EasyLoading.dismiss();
    });

    // 设备蓝牙断开连接后，刷新设备信息
    eventBus.on<BluetoothDisconnectedEvent>().listen((event) async {
      // EasyLoading.show(status: '蓝牙已断开，等待重新连接...');
      selectDevice.value = DeviceInfoModel();
    });
  }

  @override
  void onClose() {
    eventBus.destroy();
    super.onClose();
  }

  Future<void> isBindDevice() async {
    Get.back();
    if (selectDevice.value.macAddress != null) {
      EasyLoading.show(status: '${"Unbinding".tr}...');
      try {
        // 原生断开绑定
        await NvEasyPlugin().bindDevice(false);
        // 数据库断开绑定
        await DeviceService.unBindDevice(
          macAddress: selectDevice.value.macAddress!,
        );
        LocalDataBase().basicBox!.put("didConnect", null); // 解绑数据刷新缓存
        // 断开连接
        await NvEasyPlugin().startDisconnect(selectDevice.value.macAddress!);

        // 返回上一层
        Get.back();
      } finally {
        EasyLoading.dismiss();
      }
    } else {
      DialogHelper.showToastDialog("fistConnectDevice");
    }
  }

  Future<void> disConnectDeviceByUuid() async {
    EasyLoading.show(status: '${"Disconnecting".tr}...');

    try {
      if (selectDevice.value.macAddress != null) {
        // 等待断开完成
        await NvEasyPlugin().startDisconnect(selectDevice.value.macAddress!);

        // 返回上一层
        Get.back();
      }
    } finally {
      EasyLoading.dismiss();
    }
  }

  ///从Asset 复制 文件到app缓存
  Future<String?> copyAssetToAppCache(String assetPath, String filename) async {
    try {
      final directory = await getApplicationSupportDirectory();
      final appBinDir = Directory('${directory.path}/app');
      if (!appBinDir.existsSync()) {
        appBinDir.createSync(recursive: true);
      }

      final file = File('${appBinDir.path}/$filename');
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      _logger.severe("Copied asset to ${file.path}");
      return file.path;
    } catch (e) {
      _logger.severe("Error copying asset: $e");
      return null;
    }
  }

  void powerSwitch() {
    //设备关机
    //断连
  }

  ///判断是否需要升级
  Future<OtaVersionModel?> otaIsNeedUpdate(String version) async {
    try {
      OtaVersionModel? targetOta = await getOtaVersion(version);
      if (targetOta == null) {
        return null;
      }

      final targetVersion = Version.parse(targetOta.versionName);
      final currentVersion = Version.parse(version);
      _logger.severe(
        '----otaIsNeedUpdate $currentVersion  goto $targetVersion',
      );

      // 版本比较
      if (currentVersion.compareTo(targetVersion) >= 0) {
        DialogHelper.showToastDialog("OtaLatest");
        return null;
      }
      return targetOta;
    } catch (e) {
      _logger.severe("----otaIsNeedUpdate error: $e");
      return null;
    }
  }

  // 获取OTA最新版本
  Future<OtaVersionModel?> getOtaVersion(String version) async {
    try {
      ResponseApiModel? res = await HttpHelper.get(
        "/api/business/ota/check",
        // 参数只为了配合后端接口，无实际作用
        queryParameters: {'version': version},
      );
      if (res == null || res.code != 200) {
        return null;
      }
      return OtaVersionModel.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      _logger.severe("----getOtaVersion error: $e");
      return null;
    }
  }

  // 下载OTA安装包
  Future<String?> fetchOtaPackageUrl(String otaId) async {
    try {
      ResponseApiModel? res = await HttpHelper.get(
        "/api/business/ota/presign?otaId=$otaId",
      );
      if (res == null) {
        return null;
      }
      return res.data as String;
    } catch (e) {
      _logger.severe("----fetchOtaPackageUrl error: $e");
      return null;
    }
  }

  Future<OtaFirmwareModel?> getOtaFirmware() async {
    // 固件在 assets 中的路径
    const assetFirmwarePath =
        "assets/firmware/T2403_AR_SV0.7.2_HV0.0.3_20250709.bin";
    late String version;
    late String firmwareFileName;
    late String otaFilePath;
    // late OtaFirmwareModel otaFirmwareModel;

    try {
      // 模拟获取OTA升级包
      version = "0.7.2";
      firmwareFileName = "ota.bin";
    } catch (e) {
      _logger.severe('获取OTA升级包失败：$e');
      DialogHelper.showToastDialog("otafailed");
      return null;
    }

    String? path;
    try {
      // 模拟缓存OTA升级包到缓存目录
      path = await copyAssetToAppCache(assetFirmwarePath, firmwareFileName);
      if (path != null) {
        otaFilePath = path;
      }
    } catch (e) {
      _logger.severe('OTA升级包缓存到本地失败：$e');
      DialogHelper.showToastDialog("otafailed2");
      return null;
    }

    return OtaFirmwareModel(version, '', otaFilePath, firmwareFileName);
  }

  Future<void> handleOtaTest() async {
    try {
      OtaFirmwareModel? ota = await getOtaFirmware();
      if (ota != null) {
        // 执行OTA升级
        NvEasyPlugin().otaUpgrade(ota.path, ota.version);
      }
    } catch (e) {
      print(e);
    }
  }

  // OTA点击监听事件
  Future<void> handleOtaUpgrade(String version) async {
    try {
      // 检查版本
      final OtaVersionModel? targetOtaVersion = await otaIsNeedUpdate(version);
      if (targetOtaVersion == null) {
        DialogHelper.showToastDialog("OtaLatest");
        throw "已经是最新版本";
      }

      // 获取OTA升级包
      final String? otaPackageUrl = await fetchOtaPackageUrl(
        targetOtaVersion.id,
      );
      print('-----otaPackageUrl $otaPackageUrl');
      if (otaPackageUrl == null) {
        DialogHelper.showToastDialog("otafailed2");
        throw "获取版本${targetOtaVersion.versionName} 的下载地址失败！";
      }

      // 下载OTA升级包
      late File otaFile;
      try {
        final directory = await getApplicationSupportDirectory();
        final appBinDir = Directory('${directory.path}/app');
        if (!appBinDir.existsSync()) {
          appBinDir.createSync(recursive: true);
        }
        final String saveFilePath =
            "${appBinDir.path}/${targetOtaVersion.versionName}.bin";

        otaFile = await HttpHelper.downloadFile(otaPackageUrl, saveFilePath);
      } catch (e) {
        DialogHelper.showToastDialog("otafailed2");
        throw "版本${targetOtaVersion.versionName} 下载OTA升级包失败！";
      }

      // 执行OTA升级
      EasyLoading.dismiss();
      print('-----otaFile.path ${otaFile.path}');
      NvEasyPlugin().otaUpgrade(otaFile.path, targetOtaVersion.versionName);

      // 显示升级弹窗
      Get.bottomSheet(
        appController.uploadOTABin(),
        isDismissible: false, // 禁止点击外部关闭
        enableDrag: false, // 禁止下滑关闭
      );
    } catch (e) {
      // 使用日志记录器替代 print
      _logger.severe("--OTA Upgrade Error: $e");
    }
  }

  Future<void> copySericalNumber() async {
    if (selectDevice.value.macAddress != null) {
      await Clipboard.setData(
        ClipboardData(text: selectDevice.value.macAddress!),
      );
      DialogHelper.showToastDialog("copySuccess");
    }
  }

  //修改设备名称
  Future<void> editDeviceName(String editText) async {
    try {
      if (selectDevice.value.macAddress == null ||
          selectDevice.value.macAddress == "") {
        throw ("editFail");
      }

      // 使用正则表达式匹配中文，判断中文长度是否超过 16 个
      final chineseMatches = RegExp(r'[\u4e00-\u9fa5]').allMatches(editText);
      if (chineseMatches.length > 16) {
        throw ("editNameLength");
      }

      bool isLegality = await FileService.checkTextValidity(
        editText,
        CheckAction.EDIT_DEVICE,
      );
      if (!isLegality) {
        return;
      }

      EasyLoading.show();
      await DeviceService.editDeviceNameByUuid(
        macAddress: selectDevice.value.macAddress!,
        editName: editText,
      );

      final result = await NvEasyPlugin().setName(editText);
      debugPrint('-----device setName $result');
      selectDevice.update((val) {
        val?.deviceName = editText;
      });
      // 更新设备名称
      appController.syncUpdateDeviceName(
        selectDevice.value.macAddress!,
        editText,
      );
      Get.back();
    } catch (e) {
      DialogHelper.showToastDialog(e.toString());
    } finally {
      EasyLoading.dismiss();
    }

    // DeviceService.editDeviceNameByUuid(
    //   macAddress: selectDevice.value.macAddress!,
    //   editName: editText,
    // ).then((val) async {
    //   if (val) {
    //     //修改成功
    //     Get.back();
    //     selectDevice.value.deviceName = editText;
    //     selectDevice.refresh();
    //     await appController.getDeviceList();
    //     DialogHelper.showToastDialog("editSuccessful");
    //   } else {
    //     DialogHelper.showToastDialog("editFail");
    //   }
    // });
  }
}

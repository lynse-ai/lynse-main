// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/to/pubspec-plugin-platforms.

import 'dart:async';
import 'dart:convert';
import 'package:dting/store/dting_store.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

enum AudioType {
  mp3("mp3"),
  opus("opus"),
  aac("aac"),
  pcm("pcm");

  final String value;

  const AudioType(this.value);
}

/// 插件原始事件（未翻译）。供新的硬件抽象层 NeviewAdapter 订阅；
/// 旧 DtingStore 直连路径暂时保留，迁移完成后移除直连逻辑。
class NvRawEvent {
  final String type;
  final dynamic data;

  const NvRawEvent(this.type, this.data);
}

class NvEasyPlugin {
  static final MethodChannel _methodChannel = const MethodChannel(
    'nv_easy_plugin/methods',
  );
  static final EventChannel _eventChannel = const EventChannel(
    'nv_easy_plugin/events',
  );

  static final StreamController<NvRawEvent> _rawEvents =
      StreamController<NvRawEvent>.broadcast();

  /// 原始事件广播（method-call 与 event-channel 两路都会推到这里）
  static Stream<NvRawEvent> get rawEvents => _rawEvents.stream;

  static NvEasyPlugin? _instance;

  NvEasyPlugin._internal();

  factory NvEasyPlugin() {
    _instance ??= NvEasyPlugin._internal();
    return _instance!;
  }

  static void init() {
    _methodChannel.setMethodCallHandler(_handleMessage);
    _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: _handleError,
    );
  }

  static Future<dynamic> _handleMessage(dynamic message) {
    // print('收到原生消息: $message');
    var appController = Get.find<DtingStore>();
    if (message is MethodCall) {
      var methodcall = message;
      var type = methodcall.method;
      var data = methodcall.arguments;
      _rawEvents.add(NvRawEvent(type, data));
      appController.deviceState.value = type;
      switch (type) {
        case 'didDiscover':
          // 处理扫描结果
          appController.getScanDevice(data);
          print('发现设备消息: $data');
          break;
        case 'didConnect':
          // 处理连接成功
          appController.connectDevice(data);
          print('连接成功: $data');
          break;
        case 'didFailConnect':
          // 处理连接失败
          appController.connectFailDevice(data);
          print('连接失败: $data');
          break;
        case 'didDisconnect':
          // 处理断开连接
          appController.disConnectDevice();
          print('断开连接: $data');
          break;
        case 'didUpdateState':
          // 处理连接状态更新
          // 可以准备开始录音了
          print('连接状态更新: $data');
          break;
        case 'didReceiveAuthsn':
          // 处理获取SN码成功
          appController.querySN(data);
          print('获取SN码成功: $data');
          break;
        case 'didUpdateBattery':
          // 处理电量更新
          appController.updateBattery(data);
          // {"left": left, "right": right, "caseBattery":caseBattery}

          print('电量更新: $data');
          break;
        case "didUpdateBound":
          // 处理绑定状态更新
          appController.updateBound(data);
          // {"isBound": isBound, "isSuccess": isSuccess}
          print('绑定状态更新: $data');
          break;
        case "didReceiveFiles":
          // 处理硬件返回的文件列表
          // data 数据流 Unit8List
          print('didReceiveFiles 文件列表: $data');
          appController.receiveFiles(data);
          break;
        // case "bleStartGetFile":
        //   // 开始处理硬件返回的文件 - 通过蓝牙
        //   // data fileSN
        //   print('开始处理文件: $data');
        //   break;
        // case "bleDidGetFile":
        //   // 处理硬件返回的文件列表 - 通过蓝牙
        //   // data 数据流 Unit8List
        //   print('bleDidGetFile 文件列表: $data');
        //   break;
        case 'error':
          // 处理错误
          print('错误: $data');
          break;
        //录音类型
        case "didUpdateMeetingType":
          print('录音类型: $data');
          appController.updateMeetingType(data);
          break;
        //设备录音状态
        case 'didUpdateDeviceRecordStatus':
          print('didUpdateDeviceRecordStatus: $data');
          appController.updateDeviceRecordStatus(data);
          break;
        case 'sendRecordStatus':
          print('sendRecordStatus: $data');
          appController.updateDeviceRecordStatusUI(data);
          break;
        case 'didReceiveRecordMP3FilePath':
          // val fileMp3Path = mapOf("fileMp3Path" to fileMp3Path)
          appController.importPCM(data);

          print('didReceiveRecordMP3FilePath: $data');
          break;
        case 'didUpdateDownloadFileProgress':
          //val progress = mapOf("currentPacket" to currentPacket, "totalPacket" to totalPacket)
          print('didUpdateDownloadFileProgress: $data');
          appController.updateDownloadFileProgress(data);
          break;
        case 'didUpdateDownloadFileState':
          //val progress = mapOf("currentPacket" to currentPacket, "totalPacket" to totalPacket)
          print('didUpdateDownloadFileState: $data');
          appController.updateDownloadFileState(data);
          break;
        case 'fileDownloadSpeed':
          print('fileDownloadSpeed: $data');
          appController.updateDownloadFileSpeed(data);
          break;
        case 'sendDownloadAllFileUI':
          //val progress = mapOf("currentPacket" to currentPacket, "totalPacket" to totalPacket)
          print('sendDownloadAllFileUI: $data');
          appController.updateIsLoadingRecordFile(data);
          break;
        case 'deviceVersion':
          print('deviceVersion: $data');
          // val map = mapOf("softwareVersion" to softwareVersion,"hardwareVersion" to hardwareVersion)
          appController.connectingDevice.value.version =
              data["softwareVersion"];
          break;
        case 'deviceUpdateOtaStatus':
          print('deviceUpdateOtaStatus: $data');
          appController.upLoadOTABinPackage(data);
          break;
        case 'deviceWifiStatus':
          print('deviceWifiStatus: $data');
          var wifiStatus = data["wifiStatus"];
          appController.updateWifiStatus(wifiStatus);
          break;
        case 'wifiDidGetFile':
          print('wifiDidGetFile: $data');
          // WiFi快传文件完成，处理方式与蓝牙下载相同
          appController.importPCM(data);
          break;
        case 'wifiDidGetMP3File':
          print('wifiDidGetMP3File: $data');
          // WiFi快传MP3文件完成
          appController.importPCM(data);
          break;
        case 'blueTurnOff':
          print('blueTurnOff: $data');
          appController.disConnectDevice();
          appController.handleBlueTurnOff();
        default:
          print('未知消息类型: $type - $data');
      }
    }
    return Future.value(null);
  }

  static void _handleEvent(dynamic event) {
    if (event is Map) {
      print('收到原生事件: ${event['type']} - ${event['data']}');
      // 触发业务逻辑（如更新UI状态）
      var type = event['type'];
      var data = event['data'];
      _rawEvents.add(NvRawEvent(type, data));
      if (type == "deviceState") {
        var state = data["state"];
        var isConnected = data["isConnected"];
        print("设备状态：$state, 是否连接：$isConnected");
      } else if (type == "didUpdateMeetingType") {
        // 处理设备模式更新事件
        print('收到设备模式更新事件: $data');
        try {
          // 使用Get获取DtingStore实例
          final appController = Get.find<DtingStore>();
          appController.updateMeetingType(data);
        } catch (e) {
          print('获取DtingStore实例失败: $e');
        }
      }
    }
  }

  static void _handleError(Object error) {
    print('通信错误: $error');
  }

  /// 获取平台版本
  ///
  Future<String?> getPlatformVersion() async {
    return await _methodChannel.invokeMethod('getPlatformVersion');
  }

  /// 初始化 Opus 解码器
  /// @param mono true 表示单声道，false 表示立体声
  Future<String?> initOpus(bool mono) async {
    return await _methodChannel.invokeMethod('initOpus', {"mono": mono});
  }

  /// 开始扫描
  ///
  Future<String?> startScan() async {
    return await _methodChannel.invokeMethod('startScan');
  }

  /// 停止扫描
  ///
  Future<String?> stopScan() async {
    return await _methodChannel.invokeMethod('stopScan');
  }

  /// 连接设备
  ///
  /// [uuid] 设备的UUID
  Future<String?> startConnect(String uuid) async {
    return await _methodChannel.invokeMethod('startConnect', {"uuid": uuid});
  }

  /// 自动连接设备
  ///
  /// [uuid] 设备的UUID
  Future<String?> autoConnect(String uuid) async {
    return await _methodChannel.invokeMethod('autoConnect', {"uuid": uuid});
  }

  /// 断开连接
  ///
  /// [uuid] 设备的UUID
  Future<String?> startDisconnect(String uuid) async {
    return await _methodChannel.invokeMethod('startDisconnect', {"uuid": uuid});
  }

  /// 开始录音
  Future<String?> startRecord() async {
    return await _methodChannel.invokeMethod('startRecord');
  }

  /// 暂停录音
  ///
  Future<String?> pauseRecord() async {
    return await _methodChannel.invokeMethod('pauseRecord');
  }

  /// 恢复录音
  ///
  Future<String?> resumeRecord() async {
    return await _methodChannel.invokeMethod('resumeRecord');
  }

  /// 停止录音
  /// 返回包含录音文件路径的Map
  /// {
  ///   "pcmPath": PCM文件路径,
  ///   "mp3Path": MP3文件路径,
  ///   "fileName": 文件名(不含扩展名)
  /// }
  Future<Map<String, String>> stopRecord() async {
    final result = await _methodChannel.invokeMethod('stopRecord');
    print("stopRecord result: $result");
    if (result == null) {
      return {};
    }

    if (result is Map) {
      return Map<String, String>.from(result);
    }

    // 如果返回的不是Map格式，尝试解析JSON字符串
    if (result is String) {
      try {
        final Map<String, dynamic> decoded = json.decode(result);
        return Map<String, String>.from(decoded);
      } catch (e) {
        print("Error parsing stopRecord result: $e");
        // 如果是旧格式（直接返回路径字符串），将其转换为新格式
        return {
          "mp3Path": result,
          "pcmPath": result.replaceAll(".mp3", ".pcm"),
          "fileName": result.split("/").last.replaceAll(".mp3", ""),
        };
      }
    }
    return {
      "mp3Path": result ?? "",
      "pcmPath": result?.replaceAll(".mp3", ".pcm") ?? "",
      "fileName": result?.split("/")?.last.replaceAll(".mp3", "") ?? "",
    };
  }

  /// 恢复出厂设置
  ///
  Future<String?> resetDevice() async {
    return await _methodChannel.invokeMethod('resetDevice');
  }

  /// 查询设备版本
  ///
  Future<String?> queryVersion() async {
    return await _methodChannel.invokeMethod('queryVersion');
  }

  /// 查询SN码
  ///
  Future<String?> querySN() async {
    return await _methodChannel.invokeMethod('querySN');
  }

  /// 获取文件列表
  ///
  Future<String?> getFileList() async {
    return await _methodChannel.invokeMethod('getFileList');
  }

  /// 导入文件
  ///
  Future<String?> getFileByBle(String fileSN) async {
    return await _methodChannel.invokeMethod('getFileByBle', {
      "fileSN": fileSN,
    });
  }

  /// 修改名称
  ///
  /// [name] 名称
  Future<String?> setName(String name) async {
    return await _methodChannel.invokeMethod('setName', {"name": name});
  }

  /// 获取电量
  ///
  Future<String?> getBattery() async {
    return await _methodChannel.invokeMethod('getBattery');
  }

  /// 关机
  ///
  Future<String?> offtime(int minutes) async {
    return await _methodChannel.invokeMethod('offtime', {"minutes": minutes});
  }

  /// 获取绑定状态
  ///
  Future<bool?> getBindStatus() async {
    return await _methodChannel.invokeMethod('getBindStatus');
  }

  /// 绑定/解绑
  ///
  /// [isBind] 是否绑定
  Future<String?> bindDevice(bool isBind) async {
    return await _methodChannel.invokeMethod('bindDevice', {"isBind": isBind});
  }

  /// 下载音频文件 蓝牙的方式
  ///
  ///  sn: 文件列号
  Future<String> downLoadFile(int sn) async {
    var result = await _methodChannel.invokeMethod('downloadFile', {"sn": sn});
    return result;
  }

  /// 下载音频文件 wifi快传的方式
  ///
  /// sn 文件序列号
  Future<String> downLoadFileWifi(int sn) async {
    var result = await _methodChannel.invokeMethod('downloadFileOfWifi', {
      "sn": sn,
    });
    return result;
  }

  ///OTA升级
  ///
  /// @param otaFilePath OTA文件路径 @param newVersion 新版本号 @param otaFileMd5 OTA文件MD5
  Future<String> otaUpgrade(String otaFilePath, String newVersion) async {
    var result = await _methodChannel.invokeMethod('deviceOta', {
      "otaFilePath": otaFilePath,
      "newVersion": newVersion,
    });
    return result;
  }

  /// 最小化应用到后台
  ///
  Future<bool> minimizeApp() async {
    try {
      final bool result = await _methodChannel.invokeMethod('minimizeApp');
      return result;
    } catch (e) {
      print("Failed to minimize app: '$e'.");
      return false;
    }
  }
}

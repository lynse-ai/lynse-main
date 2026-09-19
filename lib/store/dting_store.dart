import 'dart:async';
import 'dart:io';
import 'package:dashed_circular_progress_bar/dashed_circular_progress_bar.dart';
import 'package:dting/even_bus.dart';
import 'package:dting/model/device_model/connect_device_files_model.dart';
import 'package:dting/model/device_model/deviceinfo_model.dart';
import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/model/file_model/folder_management_model/folder_model.dart';
import 'package:dting/model/ota/ota_update_status_model.dart';
import 'package:dting/model/personal_model/userinfo_model.dart';
import 'package:dting/model/teams_model/point_package_model.dart';
import 'package:dting/model/teams_model/teams_model.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';
import 'package:dting/router/modules/device_router.dart';
import 'package:dting/service/device_service.dart';
import 'package:dting/service/personal_service.dart';
import 'package:dting/service/point_service.dart';
import 'package:dting/service/team_service.dart';
import 'package:dting/store/change_mode_dialog.dart';
import 'package:dting/store/dting_store_ext.dart';
import 'package:dting/utils/bluetooth_utils.dart';
import 'package:dting/utils/color_util.dart';
import 'package:dting/utils/datetime_helper.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/utils/logger_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:dting/widgets/slider_indicator_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class DtingStore extends GetxController with WidgetsBindingObserver {
  static bool isRecordByCard = false;
  var isfirstLogin = false.obs;
  var userInfo = UserInfoModel(id: "", initialRewardClaimed: 0).obs; //当前登录用户
  var selectFolderFolder =
      FolderInfo(id: "-1", folderName: "allFile").obs; //当前选择文件夹
  var selectFileInfo = FileInfoModel().obs; //当前选择音频文件
  var isPlay = false.obs; //用于首页当前选择音频是否播放
  var eqota = false.obs; //判断是否超出转写配额

  var deviceState = "".obs; //记录硬件状态
  var scanDeviceList = <DeviceInfoModel>[].obs; //扫描的设备
  var bindDeviceList = <DeviceInfoModel>[].obs; //我绑定的设备
  var connectingDevice = DeviceInfoModel().obs; //连接的设备
  var bindDevice = DeviceInfoModel().obs; //当前绑定设备
  var connectDeviceFileList = <ConnectDeviceFilesModel>[].obs; //当前连接的硬件设备的存储文件
  var isShowDeviceFileList = false.obs;
  var deviceFileUploading = false.obs;
  var uploadFileSn = "".obs;
  var isUploadFile = false.obs; //现在正在同步文件

  var location = "".obs; //手机当前定位
  var deviceFilePath = "".obs; //卡片录音返回的path数据流
  var fileStreamIsUpdateOss = true.obs;

  //硬件录音
  var historyMeetingType = "".obs; //历史卡片模式
  var historyMeetingStatus = 0.obs; //历史卡片模式
  var meetingType = "".obs; //当前卡片模式
  var meetingStatus = 0.obs; //当前模式状态
  var deviceRecordStatus = "".obs; //当前录音模式
  var isRecording = false.obs; //是否是录音状态

  var batteryIconUrl = "assets/images_v3/battery60.png".obs;
  var deviceDetailBatteryIconUrl =
      "assets/images_v3/detail-device-middle-batttery.png".obs;
  var batteryString = "middleBatttery".obs;
  var showBatteryString = "--".obs; //电量显示
  // 首页控制开始录音还是停止录音
  var homeBottomStartOrStopIconUrl = "assets/images_v3/start_record.png".obs;

  // 录音状态 1 正在录音，0是没有录音
  var recordStatus = 0.obs;

  var loadingRecordFileStatus = 0.obs;
  //升级固件
  var otaUpdateProgress = 0.obs;
  var otaUpdateStatus = 0.obs;
  Rxn<OtaUpdateStatus> otaStatus = Rxn<OtaUpdateStatus>();
  var otaError = "".obs;
  ValueNotifier<double> otaProgressNotifier = ValueNotifier(0.0);

  /// 是否展示文件选择弹窗
  var isShowFileDialog = false.obs;

  var currentFile = 0.obs;
  //下载文件，当前包
  var currentPacket = 0.obs;
  //下载文件，总包
  var totalPacket = 1.obs;
  //下载文件，速度
  var downloadFileSpeed = 0.obs;

  var isShowScaning = false;

  // 添加扫描状态标记
  RxBool isScanning = false.obs;
  RxBool isRequestingPermission = false.obs;

  //当前录音文件命名
  RxString currentRecordingFileName = ''.obs; // 当前录音的文件名称
  RxString startRecordTime = ''.obs; // 当前录音的开始时间

  String get otaStatusTitle {
    if (otaStatus.value == null) return "Waiting for firmware upgrade...".tr;
    switch (otaStatus.value) {
      case OtaUpdateStatus.init:
        return "The OTA update is in progress".tr;
      case OtaUpdateStatus.progress:
        return "OTA update is in progress".tr;
      case OtaUpdateStatus.success:
        return "The OTA update was successful".tr;
      case OtaUpdateStatus.failed:
        return "The OTA update failed".tr;
      default:
        return "Unknown status".tr;
    }
  }

  var pointPackageList = <PointPackageModel>[].obs; //所有的积分套餐
  var personalPointPackageList = <PointPackageModel>[].obs; //个人积分套餐
  var teamPointPackageList = <PointPackageModel>[].obs; //团队积分套餐
  var teamsList = <TeamsModel>[].obs; //当前用户的所有team
  //重置所有数据
  resetStore() {
    bindDeviceList.value = [];
    userInfo.value = UserInfoModel(id: "");
    selectFolderFolder.value = FolderInfo(id: "-1", folderName: "allFile");
    teamsList.value = [];
    selectFileInfo.value = FileInfoModel();
    isPlay.value = false;
    eqota.value = false;
    deviceState.value = "";
    scanDeviceList.clear();
    connectingDevice.value = DeviceInfoModel();
    bindDevice.value = DeviceInfoModel();
    connectDeviceFileList.clear();
    isShowDeviceFileList.value = false;
    deviceFileUploading.value = false;
    uploadFileSn.value = "";
    location.value = "";
    deviceFilePath.value = "";
    fileStreamIsUpdateOss.value = true;
    meetingType.value = "";
    historyMeetingType.value = "";
    historyMeetingStatus.value = 0;
    meetingStatus.value = 0;
    deviceRecordStatus.value = "";
    isRecording.value = false;
    batteryIconUrl.value = "assets/images_v3/battery60.png";
    deviceDetailBatteryIconUrl.value =
        "assets/images_v3/detail-device-middle-batttery.png";
    batteryString.value = "middleBatttery";
    homeBottomStartOrStopIconUrl.value = "assets/images_v3/start_record.png";
    recordStatus.value = 0;
    otaUpdateProgress.value = 0;
    otaUpdateStatus.value = 0;
    otaStatus.value = null;
    otaError.value = "";
    otaProgressNotifier.value = 0.0;
    currentFile.value = 0;
    currentPacket.value = 0;
    totalPacket.value = 1;
    downloadFileSpeed.value = 0;
    isShowFileDialog.value = false;
    isfirstLogin.value = false;
  }

  /// 修改设备名称后，更新连接设备列表中对应的设备名
  void syncUpdateDeviceName(String macAddress, String deviceName) {
    if (connectingDevice.value.macAddress == macAddress) {
      connectingDevice.update((val) {
        val?.deviceName = deviceName;
      });
    }

    bindDeviceList.forEach((element) {
      if (element.macAddress == macAddress) {
        element.deviceName = deviceName;
      }
    });
  }

  //更新isLoadingRecordFile
  void updateIsLoadingRecordFile(data) {
    loadingRecordFileStatus.value = data["downFileStatus"];
  }

  /// 更新电池图标
  ///
  /// 更新电池图标地址
  void updateBatteryUrl() {
    final battery = connectingDevice.value.caseBattery ?? "0";
    //battery 转int
    final batteryInt = int.tryParse(battery) ?? 0;
    showBatteryString.value = batteryInt.toString(); //电量显示

    //====================================================******====================================================******
    if (batteryInt <= 20) {
      batteryIconUrl.value = "assets/images_v3/battery20.png";
      deviceDetailBatteryIconUrl.value =
          "assets/images_v3/detail-device-low-batttery.png";
      batteryString.value = "lowBatttery";
    } else if (batteryInt > 20 && batteryInt <= 40) {
      batteryIconUrl.value = "assets/images_v3/battery40.png";
      deviceDetailBatteryIconUrl.value =
          "assets/images_v3/detail-device-middle-batttery.png";
      batteryString.value = "middleBatttery";
    } else if (batteryInt > 40 && batteryInt <= 60) {
      batteryIconUrl.value = "assets/images_v3/battery60.png";
      deviceDetailBatteryIconUrl.value =
          "assets/images_v3/detail-device-middle-batttery.png";
      batteryString.value = "middleBatttery";
    } else if (batteryInt > 60 && batteryInt <= 80) {
      batteryIconUrl.value = "assets/images_v3/battery80.png";
      deviceDetailBatteryIconUrl.value =
          "assets/images_v3/detail-device-middle-batttery.png";
      batteryString.value = "middleBatttery";
    } else if (batteryInt > 80 && batteryInt <= 100) {
      batteryIconUrl.value = "assets/images_v3/battery100.png";
      deviceDetailBatteryIconUrl.value =
          "assets/images_v3/detail-device-high-batttery.png";
      batteryString.value = "highBatttery";
    } else {
      batteryIconUrl.value = "assets/images_v3/battery60.png";
      deviceDetailBatteryIconUrl.value =
          "assets/images_v3/detail-device-middle-batttery.png";
      batteryString.value = "middleBatttery";
    }
    //====================================================******====================================================******
  }

  @override
  void onReady() {}

  @override
  void onInit() {
    super.onInit();
    initPointPackageList(); //获取积分套餐
    getAllTeamList(); //获取团队列表
    getDeviceList();
    //等待4秒后开始扫描
    Future.delayed(const Duration(seconds: 5), () {
      starScan();
    });

    WidgetsBinding.instance.addObserver(this); // 注册监听
    LocalDataBase().basicBox!.put("changeModeTip", true); //更改模式的时候如果值=true 则显示
    LocalDataBase().basicBox!.put("bluetoothPermission", null); //全局蓝牙权限

    eventBus.on<BluetoothDisconnectedEvent>().listen((event) {
      // 蓝牙断开连接
      handleForeground();
      connectingDevice.value = DeviceInfoModel();
      bindDevice.value = DeviceInfoModel();
    });
  }

  @override
  void onClose() {
    handleBackground();
    eventBus.destroy();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    BluetoothUtils.instance.isBluetoothEnabled().then((val) async {
      if (!val) {
        handleBlueTurnOff();
      }
    });
    print('----didChangeAppLifecycle come in: $state');
    if (state == AppLifecycleState.paused) {
      // _handleBackground(); // 进入后台
    } else if (state == AppLifecycleState.resumed) {
      handleForeground(); // 回到前台
    }
  }

  void handleBlueTurnOff() {
    recordStatus.value = 0;
    loadingRecordFileStatus.value = 0;
    isRecording.value = false;
    isUploadFile.value = false;
    meetingStatus.value = 0;
    historyMeetingType.value = "";
    historyMeetingStatus.value = 0;
    homeBottomStartOrStopIconUrl.value = "assets/images_v3/start_record.png";
    if (Get.currentRoute == ManageDeviceRouter.managedevice) {
      print("当前路由: ${Get.currentRoute}");
      DialogHelper.showToastDialog("BluePermissions", duration: 3);
      Get.back();
    }
  }

  //获取我绑定的设备
  Future<void> getDeviceList() async {
    await DeviceService.getDeviceList().then((val) {
      bindDeviceList.value = val;
    });
  }

  //获取积分套餐
  Future<void> initPointPackageList() async {
    await PointService.getPointPackageList().then((val) {
      pointPackageList.value = val;
      personalPointPackageList.value =
          val.where((package) => package.pointsPackageType == "P").toList();
      teamPointPackageList.value =
          val.where((package) => package.pointsPackageType == "T").toList();
    });
  }

  //获取所有团队列表
  Future<void> getAllTeamList() async {
    await TeamService.getTeamListByUserId().then((val) {
      teamsList.value = val;
    });
  }

  void handleBackground() {
    final deviceUuid = connectingDevice.value.macAddress;
    print('----onClose come in disconnect device: $deviceUuid');
    if (deviceUuid != null) {
      NvEasyPlugin().startDisconnect(deviceUuid.toString());
    }
  }

  void handleForeground() {
    BluetoothUtils.instance.isBluetoothEnabled().then((value) {
      if (value && connectingDevice.value.macAddress == null) {
        starScan();
      } else {
        //如果不为空而且已经断开了则重新连接
        // if (connectingDevice.value.uuid != null) {
        //   NvEasyPlugin().startConnect(connectingDevice.value.uuid!);
        // }
      }
    });
  }

  clearStore() {
    userInfo.value = UserInfoModel(id: ""); //当前登录用户
    selectFolderFolder.value = FolderInfo(
      id: "-1",
      folderName: "allFile",
    ); //当前选择文件夹
    selectFileInfo.value = FileInfoModel(); //当前选择音频文件
    isPlay.value = false; //用于首页当前选择音频是否播放
    eqota.value = false; //判断是否超出转写配额
    deviceState.value = ""; //记录硬件状态
    scanDeviceList.value = <DeviceInfoModel>[]; //扫描的设备
    connectingDevice.value = DeviceInfoModel(); //连接的设备
    bindDevice.value = DeviceInfoModel(); //当前绑定设备
    connectDeviceFileList.value = <ConnectDeviceFilesModel>[]; //当前连接的硬件设备的存储文件
    LocalDataBase().basicBox!.put("historyConnectDeviceUuid", {
      "name": null,
      "uuid": null,
    });
  }

  Future<void> connectDevice(data) async {
    LoggerUtils.d('connectDevice 连接硬件 当前路由${Get.currentRoute}');
    try {
      isRecordByCard = true;
      connectingDevice.value = DeviceInfoModel(
        macAddress: data["uuid"],
        deviceName: data["name"],
      );
      print("连接成功后的数据 data = $data");
      LocalDataBase().basicBox!.put("didConnect", data["uuid"]); // 放缓存中
      LocalDataBase().basicBox!.put("historyConnectDeviceUuid", {
        "name": data["uuid"],
        "uuid": data["name"],
      });

      // 通知首页蓝牙连接成功
      eventBus.fire(BluetoothConnectedEvent(data['name'], data['uuid']));
    } catch (e, s) {
      LoggerUtils.e('连接设备异常：$e\n$s');
      DialogHelper.showToastDialog("connectFail");
    }

    try {
      // 首页仅获取电池，不能同时再获取其他设备信息，否则数据通道会阻塞
      await NvEasyPlugin().getBattery();
    } catch (e) {
      LoggerUtils.e('获取电池异常：$e');
      DialogHelper.showToastDialog("getBatteryFail");
    }
  }

  Future<void> getScanDevice(data) async {
    var isExist = scanDeviceList.firstWhereOrNull(
      (device) => device.macAddress == data["uuid"],
    );
    //不存在于扫描到的数据列表中就加进去
    if (isExist == null) {
      scanDeviceList.add(
        DeviceInfoModel(macAddress: data["uuid"], deviceName: data["name"]),
      );
    }

    isExist = scanDeviceList.firstWhereOrNull(
      (device) => device.macAddress == data["uuid"],
    );
    if (isExist == null) {
      print("没有此数据");
      return;
    }
    String? lastDevice = LocalDataBase().basicBox!.get("didConnect");
    print("上一个连接的设备uid connectDevice = $lastDevice");
    //判断这个硬件有没有被绑定，如果被其他人绑定则不连接
    if (lastDevice != null && data["uuid"].toString() == lastDevice) {
      // await NvEasyPlugin().startConnect(data["uuid"]);
      print("isBind(deviceUuid:  $lastDevice");
      isBind(deviceUuid: isExist);
    }
    Future.delayed(Duration(seconds: 5), () async {
      if (scanDeviceList.isEmpty) {
        await NvEasyPlugin().stopScan();
        await NvEasyPlugin().startScan();
        return;
      }
      await NvEasyPlugin().stopScan();
    });
  }

  Future<void> querySN(data) async {
    if (data["sn"] != null) {
      connectingDevice.value.serialNumber = data["sn"];
    }
    var currentRoute = Get.currentRoute;
    LoggerUtils.d('当前的路由是：$currentRoute');
    // if (currentRoute == HomeRouter.connectdevice) {
    //   NavigationUtils.toHomeIndex();
    // }
  }

  Future<void> disConnectDevice() async {
    stopRecord();
    if (connectingDevice.value.macAddress != null) {
      await NvEasyPlugin().startDisconnect(connectingDevice.value.macAddress!);
    }
    recordStatus.value = 0;
    homeBottomStartOrStopIconUrl.value = "assets/images_v3/start_record.png";
    isRecordByCard = false;
    isUploadFile.value = false;
    meetingType.value = "";
    historyMeetingType.value = "";
    historyMeetingStatus.value = 0;

    meetingStatus.value = 0;
    connectingDevice.value = DeviceInfoModel();
  }

  void updateBattery(data) {
    if (data["caseBattery"] != null) {
      var battery = data["caseBattery"];
      print("电量数据:$battery");
      connectingDevice.value.caseBattery = battery.toString();
      updateBatteryUrl();
      var homeController = Get.find<HomeIndexController>();
      homeController.updateDeviceParameters();
    }
  }

  // 插件导入PCM文件回调
  // 用于防止重复处理同一个文件的Set
  static final Set<String> _processedFiles = <String>{};

  void importPCM(data) {
    //0=>通话模式，1=>会议模式
    try {
      var homeController = Get.find<HomeIndexController>();

      /// "/data/user/0/com.lynseai.dting/cache/recordings/2025-09-11 15:39:21.mp3"
      final String? fileMp3Path = data["fileMp3Path"];
      final String recordTime = data["recordStartTime"];
      int? fileDuration = data["fileDuration"];
      final int? fileSN = data["fileSN"];
      final int? scene = data["scene"];
      print('----recordTime: $recordTime');

      // 防止重复处理同一个文
      String fileKey = fileMp3Path ?? "";
      if (fileSN != null) {
        fileKey = "fileSN_$fileSN";
      }

      if (_processedFiles.contains(fileKey)) {
        print("文件已处理过，跳过重复处理: $fileKey");
        return;
      }

      if (fileMp3Path != null && fileDuration != null) {
        // 标记文件已处理
        _processedFiles.add(fileKey);

        deviceFilePath.value = fileMp3Path;
        final fileSize = File(deviceFilePath.value).lengthSync();
        print("------importPCM 时长：$fileDuration 大小：$fileSize");
        if (fileStreamIsUpdateOss.value) {
          homeController.updateFileByOss(
            multiFilePath: deviceFilePath.value,
            fileSize: fileSize,
            fileDuration: fileDuration,
            scene: scene,
            recordTime: recordTime,
          );
        }

        if (isShowDeviceFileList.value) {
          deviceFileUploading.value = false;
          Get.back();
        }

        // 文件下载完成，关闭loading
        EasyLoading.dismiss();
        // DialogHelper.showToastDialog("importSuccessful");
      } else {
        DialogHelper.showToastDialog("uploadFail");
        EasyLoading.dismiss();
      }
    } catch (error) {
      print("importPCM error: $error");
      EasyLoading.dismiss();
      DialogHelper.showToastDialog("uploadFail");
    }
  }

  void updateBound(data) {
    if (data["isBound"] != null) {
      var bound = data["isBound"];
      int boundState = 0;
      bindDevice.value = DeviceInfoModel();
      if (bound == true) {
        boundState = 1;
        bindDevice.value = connectingDevice.value;
      }
      connectingDevice.value.bindStatus = boundState;
    }
  }

  void receiveFiles(data) {
    print('receiveFiles data: $data');

    // 清理已处理的文件记录，防止内存泄漏
    _processedFiles.clear();

    List<ConnectDeviceFilesModel> modelList = [];
    if (data is List) {
      for (var item in data) {
        if (item is Map) {
          modelList.add(
            ConnectDeviceFilesModel(
              sn: item["sn"].toString(),
              size: item["size"].toString(),
              endTimestamp: item["endTimestamp"].toString(),
              startTimestamp: item["startTimestamp"].toString(),
              name: item["name"].toString(),
              scene: item["scene"].toString(),
            ),
          );
        }
      }
    }
    connectDeviceFileList.value = modelList;
    // if (connectDeviceFileList.isEmpty ||
    //     currentFile.value == connectDeviceFileList.length) {
    //   isUploadFile.value = false;
    // } else {
    //   isUploadFile.value = true;
    // }

    if (isShowFileDialog.value) {
      isShowFileDialog.value = false;
      Future.delayed(const Duration(seconds: 2), () {
        var homeController = Get.find<HomeIndexController>();
        homeController.showConnectDeviceFileDialog();
      });
    }
  }

  void updateMeetingType(data) {
    print('updateMeetingType: $data');
    if (data["mode"] == null) return;

    var mode = data["mode"];
    bool? showTip = LocalDataBase().basicBox!.get("changeModeTip");

    // 先保存旧值
    String oldType = meetingType.value;
    int oldTypeStatus = meetingStatus.value;

    // 再更新新模式
    if (mode == 1) {
      meetingType.value = "Call mode".tr;
      meetingStatus.value = 1;
      print('设备模式更新为: 通话模式');
    } else {
      meetingType.value = "Meeting mode".tr;
      meetingStatus.value = 0;
      print('设备模式更新为: 会议模式');
    }

    // 更新历史
    if (oldType.isNotEmpty) {
      historyMeetingType.value = oldType;
      historyMeetingStatus.value = oldTypeStatus;
    }

    // 判断是否需要提示
    if (recordStatus.value == 1 &&
        oldType.isNotEmpty &&
        meetingType.value != oldType &&
        showTip == true) {
      Get.bottomSheet(ChangeModeDialog());
    } else {
      print("recordStatus.value:${recordStatus.value}");
      print("meetingType.value:${meetingType.value}");
      print("historyMeetingType.value:${historyMeetingType.value}");
      print("showTip.value:$showTip");
    }
  }

  /**
   * 更新WiFi状态
   *  OPENING(0),
   *  OPENED(1),
   *  CONNECTING(2),
   *  CONNECTED(3),
   *  STOPPING(4),
   *  STOPPED(5);
   */
  void updateWifiStatus(wifiStatus) {
    print('WiFi状态更新: $wifiStatus');

    switch (wifiStatus) {
      case 0: // OPENING
        print('WiFi热点开启中...');
        break;
      case 1: // OPENED
        print('WiFi热点已开启');
        break;
      case 2: // CONNECTING
        print('正在连接WiFi热点...');
        break;
      case 3: // CONNECTED
        print('已连接到WiFi热点，开始快传');
        // WiFi连接成功后关闭loading
        EasyLoading.dismiss();
        break;
      case 4: // STOPPING
        print('WiFi快传停止中...');
        break;
      case 5: // STOPPED
        print('WiFi快传已停止');
        // 快传结束后重新开始扫描
        starScan();
        break;
      default:
        print('未知WiFi状态: $wifiStatus');
    }
  }

  void updateDownloadFileProgress(data) {
    //val progress = mapOf("currentPacket" to currentPacket, "totalPacket" to totalPacket, "currentNumber" to currentNumber)
    currentPacket.value = data["currentPacket"] ?? 0;
    totalPacket.value =
        (data["totalPacket"] ?? 1).clamp(1, double.infinity).toInt();
    currentFile.value = data["currentNumber"] ?? 0;

    // 判断是否全部下载完成
    if (connectDeviceFileList.isEmpty ||
        (connectDeviceFileList.length == currentFile.value &&
            currentPacket.value == totalPacket.value)) {
      isUploadFile.value = false;
    } else {
      isUploadFile.value = true;
    }
  }

  void updateDownloadFileState(data) {
    isUploadFile.value = data["isDownloading"] == 1;
  }

  void updateDownloadFileSpeed(data) {
    int speed = data["speedKbps"] ?? 0;
    // 确保速度值是有效的数字
    if (speed.isFinite && speed >= 0) {
      downloadFileSpeed.value = speed;
    } else {
      downloadFileSpeed.value = 0;
    }
  }

  void updateDeviceRecordStatus(data) {
    if (data["status"] != null) {
      var status = data["status"];
      var mode = data["mode"];
      var aiMode = data["aiMode"];
      updateRecordIconUrl(status);
      if (status == 1) {
        isRecording.value = true;
        //开启录音
        NvEasyPlugin().initOpus(true);
        currentRecordingFileName.value = DateTimeHelper.dateTimeCoverTOString(
          DateTime.now(),
        );
        startRecordTime.value = DateTimeHelper.dateTimeCoverTOString(
          DateTime.now(),
        );
        NvEasyPlugin().startRecord();
        // 类型和状态的赋值
        deviceRecordStatus.value =
            mode == 1 ? "Call recording..".tr : "Meeting recording..".tr;
        meetingType.value = mode == 1 ? "Call mode".tr : "Meeting mode".tr;
        meetingStatus.value = mode;

        historyMeetingType.value = meetingType.value;
        historyMeetingStatus.value = mode;
      } else {
        isRecording.value = false;
        //停止录音
        deviceRecordStatus.value = "";
        // meetingStatus.value = 0;
        meetingType.value = "";
        NvEasyPlugin().stopRecord();
      }
    }
  }

  //启动录音
  void startRecord() {
    currentRecordingFileName.value = DateTimeHelper.dateTimeCoverTOString(
      DateTime.now(),
    );
    startRecordTime.value = DateTimeHelper.dateTimeCoverTOString(
      DateTime.now(),
    );
    //开启录音
    NvEasyPlugin().initOpus(true);
    NvEasyPlugin().startRecord();
  }

  //停止录音
  void stopRecord() {
    if(isRecording.value) {
      NvEasyPlugin().stopRecord();
    }
  }

  void updateDeviceRecordStatusUI(data) {
    if (data["status"] != null) {
      var status = data["status"];
      var mode = data["mode"];
      updateRecordIconUrl(status);
      if (status == 1) {
        currentRecordingFileName.value = DateTimeHelper.dateTimeCoverTOString(
          DateTime.now(),
        );
        startRecordTime.value = DateTimeHelper.dateTimeCoverTOString(
          DateTime.now(),
        );
        //开启录音
        // 类型和状态的赋值
        deviceRecordStatus.value =
            mode == 1 ? "Call recording..".tr : "Meeting recording..".tr;
        meetingType.value = mode == 1 ? "Call mode".tr : "Meeting mode".tr;
        meetingStatus.value = mode;
        historyMeetingType.value = meetingType.value;
        historyMeetingStatus.value = mode;
      } else {
        //停止录音
        deviceRecordStatus.value = "";
        meetingType.value = "";
      }
    }
  }

  //更新开始或者停止录音的iconUrl
  void updateRecordIconUrl(status) {
    recordStatus.value = status;
    // 1是正在录音

    connectingDevice.value.macAddress != null &&
            connectingDevice.value.macAddress != ""
        ? homeBottomStartOrStopIconUrl.value =
            status == 1
                ? "assets/images_v3/stop_record.png"
                : "assets/images_v3/start_record.png"
        : "assets/images_v3/start_record.png";
  }

  // 监听OTA升级状态
  Timer? _upgradeTimer;
  void upLoadOTABinPackage(data) {
    // {status: 1, progress: 38, upgradedSize: 282240, error: }
    //  STARTED(0), 升级开始
    //   PROGRESS(1), 升级中
    //   SUCCESS(2), 升级成功
    //   FAILED(3) 升级失败
    final int upgradeStatus = data['status'];
    final int upgradeProgress = data['progress'];
    final String upgradeError = data['error'];

    // 如果计时器存在，说明上次点击还在防抖时间内，直接返回
    if (_upgradeTimer != null && upgradeStatus == otaStatus.value) {
      return;
    }

    // 设置防抖计时器，3秒内不再响应点击

    _upgradeTimer = Timer(const Duration(seconds: 2), () {
      _upgradeTimer = null;
    });

    print(
      '======upLoadOTABinPackage ${upgradeStatus} ${upgradeProgress} ${upgradeError}',
    );
    try {
      otaStatus.value = OtaUpdateStatus.fromValue(data['status']);
      if (otaStatus.value == null) {
        DialogHelper.showToastDialog("otaError");
        return;
      }

      late StreamSubscription lostDeviceSub;
      if (otaStatus.value == OtaUpdateStatus.progress) {
        // 更新进度值
        otaUpdateProgress.value = upgradeProgress;
        // 同时更新ValueNotifier以确保UI正确更新
        otaProgressNotifier.value = upgradeProgress.toDouble();
      } else if (otaStatus.value == OtaUpdateStatus.success) {
        DialogHelper.showToastDialog('OTA升级成功，卡片将自动重启，请稍后！');
        otaError.value = "";
        otaUpdateProgress.value = 0;
        otaStatus.value = OtaUpdateStatus.init;
        Get.back();
        // 更新成功后，监听连接状态后重新连接
      } else if (otaStatus.value == OtaUpdateStatus.failed) {
        otaError.value = upgradeError;
      }
    } catch (e) {
      print("~~~~~~upLoadOTABinPackage call error: $e");
      DialogHelper.showToastDialog("${e.toString()}");
    }
  }

  Widget uploadOTABin() {
    return Obx(
      () => SafeArea(
        top: true,
        bottom: false,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 15.w),
          decoration: BoxDecoration(
            color: ColorUtil.fromHexString("#FFFFFF"),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.w),
              topRight: Radius.circular(16.w),
            ),
            boxShadow: [
              BoxShadow(
                offset: Offset(0, -0.5),
                blurRadius: 0,
                spreadRadius: 0,
                color: ColorUtil.fromHexString("#E5E6EB"),
              ),
              BoxShadow(
                offset: Offset(0, -5),
                blurRadius: 0,
                spreadRadius: 0,
                color: ColorUtil.fromHexString("#E5E6EB", 0.2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SliderIndicatorBar(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 15.w),
                  _buildOtaProgressStatus(
                    title: otaStatusTitle,
                    status: otaStatus.value ?? OtaUpdateStatus.init,
                    valueNotifier: otaProgressNotifier,
                    progress: (otaUpdateProgress.value).toDouble(),
                    error: otaError.value,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 判断这个硬件有没有被别人绑定
  Future<void> isBind({required DeviceInfoModel deviceUuid}) async {
    try {
      if (deviceUuid.macAddress == null || deviceUuid.macAddress == "") {
        DialogHelper.showToastDialog("connectFail");
        return;
      }
      var val = await DeviceService.getBindList(
        macAddressList: [deviceUuid.macAddress!],
      );
      var data = val.firstWhereOrNull(
        (item) => item.macAddress == deviceUuid.macAddress,
      );
      if (data == null) return;

      if (data.bindStatus == 0) {
        // 绑定硬件
        var isBindSuccess = await DeviceService.bindDevice(
          macAddress: deviceUuid.macAddress!,
          deviceName: deviceUuid.deviceName,
          serialNumber: deviceUuid.serialNumber,
          version: deviceUuid.version,
        );
        if (isBindSuccess) {
          var value = await PersonalService.getCurrentUserLoginInfo();
          if (value != null) {
            userInfo.value = value;
          }
          await NvEasyPlugin().startConnect(deviceUuid.macAddress!);
          await NvEasyPlugin().bindDevice(true);
        } else {
          DialogHelper.showToastDialog("connectFail");
        }
      } else {
        if (data.isBoundByMe == 1) {
          await NvEasyPlugin().startConnect(deviceUuid.macAddress!);
          await NvEasyPlugin().bindDevice(true);
        } else {
          DialogHelper.showToastDialog(
            "isBindTip".trParams({
              'deviceName': data.phone ?? "", // 这里是动态数据
            }),
          );
        }
      }
    } catch (e) {
      print("连接错误：$e");
    }
  }

  void connectFailDevice(data) {
    var connectStatus = data["linkstatus"];
    if (connectStatus == 1) {
      // 蓝牙断开连接
      DialogHelper.showToastDialog("connectFail");
      eventBus.fire(BluetoothDisconnectedEvent());
    } else {
      DialogHelper.showToastDialog("connectSuccessful");
    }
  }
}

Widget _buildOtaProgressStatus({
  required String title,
  required OtaUpdateStatus status,
  required ValueNotifier<double> valueNotifier,
  double progress = 0,
  String? error,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      if (status == OtaUpdateStatus.init)
        SizedBox(
          height: 18.h,
          child: Image.asset(
            'assets/images/device/icon_nodata.png',
            width: 48.w,
            height: 48.w,
          ),
        ),
      if (status == OtaUpdateStatus.progress)
        Container(
          height: 18.h,
          padding: EdgeInsets.all(10),
          child: DashedCircularProgressBar.aspectRatio(
            aspectRatio: 1,
            valueNotifier: valueNotifier,
            startAngle: 225,
            sweepAngle: 275,
            progress: progress,
            animation: true,
            foregroundStrokeWidth: 15,
            backgroundStrokeWidth: 15,
            child: Center(
              child: ValueListenableBuilder<double>(
                valueListenable: valueNotifier,
                builder: (context, value, child) {
                  return Text(
                    '${value.toInt()}%',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
          ),
        ),
      if (status == OtaUpdateStatus.success)
        SizedBox(
          height: 18.h,
          child: Image.asset(
            'assets/images/device/icon_success.png',
            width: 48.w,
            height: 48.w,
          ),
        ),
      if (status == OtaUpdateStatus.failed) ...[
        SizedBox(height: 10),
        Image.asset(
          'assets/images/device/icon_failed.png',
          width: 48.w,
          height: 48.w,
        ),
        SizedBox(height: 6),
        Obx(
          () => Text(
            DtingStore().otaError.value,
            style: TextStyle(
              color: Color.fromRGBO(0, 0, 0, 0.35),
              fontSize: 14.w,
            ),
          ),
        ),
      ],
    ],
  );
}

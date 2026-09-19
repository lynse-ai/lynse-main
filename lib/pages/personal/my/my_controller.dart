import 'dart:async';
import 'dart:io';

import 'package:dting/enums/permission_enum.dart';
import 'package:dting/model/personal_model/userinfo_model.dart';
import 'package:dting/model/teams_model/teams_model.dart';
import 'package:dting/pages/device/voice_details/voicedetails_controller.dart';
import 'package:dting/pages/home/home_index/homeindex_controller.dart';
import 'package:dting/pages/home/folder_manage/folder_manage_controller.dart';
import 'package:dting/pages/login/mobilelogin/mobilelogin_controller.dart';
import 'package:dting/pages/personal/my/point_transfer.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/plugin/nv_easy_plugin.dart';
import 'package:dting/service/file_service.dart';
import 'package:dting/service/login_service.dart';
import 'package:dting/service/permission_service.dart';
import 'package:dting/service/personal_service.dart';
import 'package:dting/service/team_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/image_helper.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/utils/navigation_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class MyController extends GetxController {
  var appController = Get.find<DtingStore>();
  var teamFileController = Get.find<TeamFileController>();
  var transPointController = TextEditingController(); //转移的积分

  var tempSelectTeam = TeamsModel.genDefault().obs;
  @override
  void onInit() {
    super.onInit();
    getAllTeamList();
    initUserInfo();
    // initCalculationUse();
    // initPointUsed();
  }

  @override
  void dispose() {
    super.dispose();
  }

  //重置数据
  void resetData() {
    tempSelectTeam.value = TeamsModel.genDefault();
  }

  //获取团队数据
  Future<void> getAllTeamList() async {
    if (appController.teamsList.isEmpty) {
      await TeamService.getTeamListByUserId().then((val) {
        appController.teamsList.value = val;
      });
    }
  }

  //初始化用户信息
  void initUserInfo() async {
    try {
      var userinfo = await PersonalService.getCurrentUserLoginInfo();
      if (userinfo != null) {
        appController.userInfo.value = userinfo;
        appController.userInfo.refresh();
      }
    } catch (e) {
      print("initUserInfo error: $e");
    }
  }

  // 修改手机号
  void editPhone(String editPhone) async {
    var userId = appController.userInfo.value.id;
    await EasyLoading.show();
    // await PersonalService.editPhone(userId, editPhone).then((val) async {
    //   if (val != null) {
    //     if (val.code == 200) {
    //       await PersonalService.getCurrentUserLoginInfo().then((user) {
    //         if (user != null) {
    //           // appController.userInfo.value = user;
    //           appController.userInfo.update((val) {
    //             val?.phone = editPhone;
    //           });
    //         }
    //       });
    //     } else {
    //       var message = val.msg;
    //       DialogHelper.showToastDialog(message);
    //     }
    //   }
    // });
    await EasyLoading.dismiss();
  }

  // 修改昵称
  void editNiceName(String editNiceNameString) async {
    var userId = appController.userInfo.value.id;
    await EasyLoading.show();
    if (editNiceNameString.isNotEmpty) {
      UserInfoModel editUser = UserInfoModel(
        id: userId,
        nickname: editNiceNameString,
      );
      await PersonalService.editUserInfo(editUser).then((val) async {
        if (val != null) {
          if (val.code == 200) {
            await PersonalService.getCurrentUserLoginInfo().then((user) {
              if (user != null) {
                // appController.userInfo.value = user;
                appController.userInfo.update((val) {
                  val?.nickname = editNiceNameString;
                });
              }
            });
          } else {
            var message = val.msg;
            DialogHelper.showToastDialog(message);
          }
        }
      });
    } else {
      DialogHelper.showToastDialog("cannotEmpty");
    }
    NavigationUtils.back();
    await EasyLoading.dismiss();
  }

  // //选择方式上传头像
  Future<void> swithchImageSource(String value) async {
    final isGallery = value.toLowerCase() == "gallery";
    final isIOS = Platform.isIOS;

    // 检查对应权限类型
    final permission =
        isGallery ? PermissionEnum.photos : PermissionEnum.camera;
    final hasPermission = await PermissionService.instance.checkPermission(
      permission,
    );

    if (hasPermission) {
      // 已授权，直接打开
      _pickImage(isGallery ? ImageSource.gallery : ImageSource.camera);
      return;
    }

    // 从本地读取是否已显示过自定义提示
    final hintKey =
        isGallery
            ? "hasShownGalleryPermissionHint"
            : "hasShownCameraPermissionHint";
    final hasShownHint = await LocalDataBase().basicBox!.get(hintKey) ?? false;

    if (!isIOS) {
      //如果是IOS直接跳过弹窗
      if (!hasShownHint) {
        // 第一次弹自定义提示
        final ok = await _showPermissionHintDialog(isGallery);
        if (!ok) return; // 用户取消
        await LocalDataBase().basicBox!.put(hintKey, true);
      }
    }

    // 走系统权限请求
    final granted =
        isGallery
            ? await PermissionService.instance.requestPhotosPermissions(
              'photoPermissionRequest'.tr,
            )
            : await PermissionService.instance.requestCameraPermissions();

    if (granted) {
      _pickImage(isGallery ? ImageSource.gallery : ImageSource.camera);
    } else {
      DialogHelper.showToastDialog(
        isGallery ? 'photoPermiss' : 'cameraPermiss',
      );
    }
  }

  // 打开相册或相机
  void _pickImage(ImageSource source) {
    ImageHelper.getPhoto(source).then((value) {
      if (value != null) {
        editUserImage(value);
      } else {
        NavigationUtils.back();
      }
    });
  }

  // 自定义权限提示弹窗
  Future<bool> _showPermissionHintDialog(bool isGallery) {
    final completer = Completer<bool>();

    DialogHelper.showTipDialog(
      message: isGallery ? 'photoPermiss' : 'cameraPermiss',
      title: "Permission", //isGallery ? '相册权限请求' : '相机权限请求',
      okText: 'permissionAllow',
      okOntap: () {
        if (!completer.isCompleted) completer.complete(true);
        Get.back();
      },
      cancelText: 'permissionDeny',
      cancelOntap: () {
        if (!completer.isCompleted) completer.complete(false);
        Get.back();
      },
    );

    return completer.future;
  }

  //设置头像
  editUserImage(XFile value) async {
    NavigationUtils.back();
    var userId = appController.userInfo.value.id;

    await EasyLoading.show();

    try {
      final file = File(value.path);
      final fileBytes = await file.readAsBytes();

      var uploadImage = await FileService.uploadAvatar(
        filename: value.name,
        uploadPathBytes: fileBytes,
      );
      if (uploadImage != null) {
        UserInfoModel editUser = UserInfoModel(
          id: userId,
          avatarUrl: uploadImage,
        );
        var edit = await PersonalService.editUserInfo(editUser);

        if (edit != null) {
          if (edit.code == 200) {
            var userinfo = await PersonalService.getCurrentUserLoginInfo();
            if (userinfo != null) {
              appController.userInfo.value = userinfo;
            } else {
              DialogHelper.showToastDialog("editFail");
            }
          } else {
            var message = edit.msg;
            DialogHelper.showToastDialog(message);
          }
        }
      } else {
        DialogHelper.showToastDialog("editFail");
      }
    } catch (e) {
      DialogHelper.showToastDialog("editFail");
      await EasyLoading.dismiss();
    }
    await EasyLoading.dismiss();
  }

  //退出登录
  Future<void> loginOut() async {
    await EasyLoading.show();
    try {
      // 清除所有 Controller
      await LoginService.logout();
      if (appController.connectingDevice.value.macAddress != null) {
        await NvEasyPlugin().startDisconnect(
          appController.connectingDevice.value.macAddress!,
        );
        appController.disConnectDevice();
      }

      LocalDataBase.cleatCache();
      // 清空当前用户
      appController.clearStore();
      Get.find<TeamFileController>().resetData();
      Get.find<MyController>().resetData();

      if (Get.isRegistered<VoiceDetailsController>()) {
        Get.find<VoiceDetailsController>().resetData();
      } else {
        // 可选：打印日志或处理异常情况
        print("VoiceDetailsController 未注册");
      }
      appController.resetStore();

      Get.delete<SideBarController>(force: true);
      Get.delete<MobileLogInController>(force: true);
      Get.delete<HomeIndexController>(force: true);
      Get.delete<TeamFileController>(force: true);
      //注销账号 清除文件上传梯队

      NavigationUtils.toMobileLogIn();
    } catch (e) {
      print("注销账号 ：$e");
    }
    await EasyLoading.dismiss();
  }

  //注销账号
  void cancelAccount() {
    PersonalService.cancelAccount().then((value) {
      if (value != null) {
        if (value.code == 200) {
          loginOut();
        } else {
          var message = value.msg;
          DialogHelper.showToastDialog(message);
        }
      }
    });
  }

  //转移积分
  Future<void> transPoint() async {
    var tempTransPoint = transPointController.text;
    if (tempTransPoint.trim().isEmpty) {
      DialogHelper.showToastDialog("inputPointNumber");
      return;
    }
    if (tempSelectTeam.value.id == "" || tempSelectTeam.value.id == "-1") {
      DialogHelper.showToastDialog("selectTeam");
      return;
    }
    if (int.parse(tempTransPoint) >
        appController.userInfo.value.remainPointsAmountInt) {
      DialogHelper.showToastDialog("nsufficientPoints");
      return;
    }
    try {
      await EasyLoading.show();
      TeamService.allocatePoints(
        pointsAmount: int.parse(tempTransPoint),
        teamId: tempSelectTeam.value.id,
      ).then((val) {
        if (val != null) {
          if (val.code == 200) {
            PersonalService.getCurrentUserLoginInfo().then((val) {
              appController.userInfo.value = val!;
            });
            if (tempSelectTeam.value.id ==
                appController.userInfo.value.teamId) {
              teamFileController.getCurrentTeamDetail();
            }
            Get.back();
            DialogHelper.showToastDialog("pointSuccessful");
          } else {
            var message = val.msg;
            DialogHelper.showToastDialog(message);
          }
        }
      });
    } catch (e) {
      print("allocatePoints error: $e");
    } finally {
      await EasyLoading.dismiss();
    }
  }

  Future<void> showTransPointBott() async {
    if (appController.teamsList.isEmpty) {
      await appController.getAllTeamList();
    }
    tempSelectTeam.value = TeamsModel.genDefault();
    transPointController.text = "";
    Get.bottomSheet(PointTransferWidget(), isScrollControlled: true);
  }
}

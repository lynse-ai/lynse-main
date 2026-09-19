import 'package:dting/model/device_model/deviceinfo_model.dart';
import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/model/login_model/login_request_model.dart';
import 'package:dting/model/login_model/login_response_model.dart';
import 'package:dting/model/teams_model/teams_model.dart';
import 'package:dting/pages/device/bootstrapoperation/bootstrapoperation_page.dart';
import 'package:dting/router/modules/device_router.dart';
import 'package:dting/router/modules/home_router.dart';
import 'package:dting/router/modules/login_router.dart';
import 'package:dting/router/modules/lynse_router.dart';
import 'package:dting/router/modules/payment_router.dart';
import 'package:dting/router/modules/personal_router.dart';
import 'package:dting/router/modules/team_router.dart';
import 'package:get/get.dart';

class NavigationUtils {
  static void back({dynamic result}) {
    Get.back(result: result);
  }

  //Login in
  static void toAgreement({required String text, required String title}) {
    Get.toNamed(
      LoginRouter.agreement,
      arguments: {'text': text, 'title': title},
    );
  }

  static void toForgotpassword() {
    Get.toNamed(LoginRouter.forgotpassword);
  }

  static void toBindMobilePhone({
    required LoginResponsetModel loginRespones,
    required LoginRequestModel loginRequest,
  }) {
    Get.toNamed(
      LoginRouter.bindmobilephone,
      arguments: {'loginRespones': loginRespones, 'loginRequest': loginRequest},
    );
  }

  static void toBindMobilePhoneWithSetPwd({
    required LoginRequestModel loginRequest,
    required LoginResponsetModel loginRespones,
  }) {
    Get.toNamed(
      LoginRouter.bindmobilephonewithsetpwd,
      arguments: {'loginRespones': loginRespones, 'loginRequest': loginRequest},
    );
  }

  static void toMobileLogIn() {
    Get.toNamed(LoginRouter.mobilelogin);
  }

  // static void toPhoneCodeLogin() {
  //   Get.toNamed(LoginRouter.phoneCodeLogin);
  // }

  //Home
  static void toShareTeam() {
    Get.toNamed(TeamRouter.shareteam);
  }

  static void toFolderManage() {
    Get.toNamed(HomeRouter.folderManage);
  }

  static void toHomeTip() {
    Get.toNamed(HomeRouter.hometip);
  }

  static void toVoicePlay(FileInfoModel currentVoiceFile) {
    Get.toNamed(
      HomeRouter.voiceplay,
      arguments: {'currentVoiceFile': currentVoiceFile},
    );
  }

  static void toRecycleBin() {
    Get.toNamed(HomeRouter.recyclebin);
  }

  /// 搜索设备
  static void toBootstrapOperation() {
    Get.bottomSheet(
      const BootstrapOperationPage(),
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
    );
  }

  //我连接的设备列表
  static void toConnectDevice() {
    Get.toNamed(HomeRouter.connectdevice);
  }

  //附近搜索到的设备列表
  static void toSearchDevice() {
    Get.toNamed(HomeRouter.searchDevice);
  }

  static void replaceHomePrompt() {
    Get.offAllNamed(HomeRouter.homeprompt);
  }

  static void toHomePrompt() {
    Get.toNamed(HomeRouter.homeprompt);
  }

  static void replaceHomeIndex() {
    // 新版 lynse 外壳（主页/设备/记录）；旧首页保留可回退：
    // Get.offNamed(HomeRouter.homeindex);
    Get.offNamed(LynseRouter.shell);
  }

  static void toHomeIndex() {
    Get.toNamed(HomeRouter.homeindex);
  }

  static void toSearch() {
    Get.toNamed(HomeRouter.search);
  }

  static void toConcel() {
    Get.toNamed(HomeRouter.concel);
  }

  static void toVoiceDetails({bool isPersonalFile = true}) {
    Get.toNamed(
      HomeRouter.voicedetails,
      arguments: {'isPersonalFile': isPersonalFile},
    );
  }

  //device
  static void toManageDevice(DeviceInfoModel device) {
    Get.toNamed(
      ManageDeviceRouter.managedevice,
      arguments: {'selectDevice': device},
    );
  }

  //personal
  static void toLanguagePage() {
    Get.toNamed(PersonalRouter.language);
  }

  static void toHelpAndFeedBack() {
    Get.toNamed(PersonalRouter.help);
  }

  static void toPointHistory() {
    Get.toNamed(PersonalRouter.pointhistory);
  }

  static void toReport() {
    Get.toNamed(PersonalRouter.report);
  }

  static void toHAbout() {
    Get.toNamed(PersonalRouter.about);
  }

  static void toMy() {
    Get.toNamed(PersonalRouter.my);
  }

  static void toUser() {
    Get.toNamed(PersonalRouter.user);
  }

  static void toDownloadFile(String folder) {
    Get.toNamed(PersonalRouter.downloadfile, arguments: {'folder': folder});
  }

  static void toDownloadFolder() {
    Get.toNamed(PersonalRouter.downloadfolder);
  }

  static void toPurchasePoints() {
    Get.toNamed(PersonalRouter.purchase);
  }

  //Team
  static void toAddSeats() {
    Get.toNamed(TeamRouter.addseats);
  }

  static void toShareTeamMembers(TeamsModel team) {
    Get.toNamed(TeamRouter.shareTeamMembers, arguments: {'selectTeam': team});
  }

  static void toMembers() {
    Get.toNamed(TeamRouter.members);
  }

  static void toTeamPurchasePoints() {
    Get.toNamed(TeamRouter.teampurchase);
  }

  static void toTeams() {
    Get.toNamed(TeamRouter.teams);
  }

  static void toSearchTeams() {
    Get.toNamed(TeamRouter.searchTeams);
  }

  static void toShareTeamFile() {
    Get.toNamed(TeamRouter.shareTeamFile);
  }

  static void toChangeMembers() {
    Get.toNamed(TeamRouter.changeMembers);
  }

  static void toTeamsVoiceDetail() {
    Get.toNamed(TeamRouter.teamsVoiceDetail);
  }

  static void toTeamPointHistory() {
    Get.toNamed(TeamRouter.teamPointHistory);
  }

  // Payment
  static void toPaymentSuccess(String amount) {
    Get.toNamed(
      PaymentRouter.paymentSuccess,
      arguments: {'amount': amount},
    );
  }
}

import 'package:get/get.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/service/personal_service.dart';

class PaymentSuccessController extends GetxController {
  final DtingStore appController = Get.find<DtingStore>();
  final String amount;

  PaymentSuccessController({required this.amount});

  @override
  void onInit() {
    super.onInit();
    // 支付成功后，可以在这里更新用户信息或执行其他操作
    updateUserInfo();
  }

  // 更新用户信息
  Future<void> updateUserInfo() async {
    try {
      // 从服务器获取最新的用户信息
      var userInfo = await PersonalService.getCurrentUserLoginInfo();
      if (userInfo != null) {
        appController.userInfo.value = userInfo;
      }
    } catch (e) {
      print('更新用户信息失败: $e');
    }
  }

  // 返回上一页
  void goBack() {
    Get.back();
  }
}
import 'package:dting/pages/payment/payment_success_controller.dart';
import 'package:get/get.dart';

class PaymentSuccessBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() {
      // 从路由参数中获取支付金额
      final String amount = Get.arguments['amount'] ?? '0';
      return PaymentSuccessController(amount: amount);
    });
  }
}

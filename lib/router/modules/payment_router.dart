import 'package:dting/pages/payment/payment_success_binding.dart';
import 'package:dting/pages/payment/payment_success_page.dart';
import 'package:get/get.dart';

class PaymentRouter {
  static final paymentSuccess = '/paymentSuccess';

  static final pages = [
    GetPage(
      name: paymentSuccess,
      page: () => PaymentSuccessPage(
        amount: Get.arguments['amount'] ?? '0',
      ),
      binding: PaymentSuccessBinding(),
    ),
  ];
}
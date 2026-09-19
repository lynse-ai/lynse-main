// import 'dart:async'; 
// import 'package:dting/model/payment/order_verify_transaction_model.dart';
// import 'package:dting/model/personal_model/vip_package_model.dart';
// import 'package:dting/service/payment_service.dart';
// import 'package:dting/service/personal_service.dart';
// import 'package:dting/store/dting_store.dart';
// import 'package:dting/utils/permission_helper.dart';
// import 'package:flutter_easyloading/flutter_easyloading.dart';
// import 'package:fluwx/fluwx.dart';
// import 'package:get/get.dart';
// import 'package:in_app_purchase/in_app_purchase.dart';

// class VipController extends GetxController {
//   var appController = Get.find<DtingStore>();
//   var monthOrYear = 0.obs;
//   var allVipPackageList = <VIPackageModel>[].obs;

//   var freePackage = VIPackageModel().obs;
//   var yearProPackage = VIPackageModel(price: 0).obs;
//   var yearUnlimitedPackage = VIPackageModel(price: 0).obs;
//   var mothProPackage = VIPackageModel(price: 0).obs;
//   var mothUnlimitedPackage = VIPackageModel(price: 0).obs;

//   Fluwx fluwx = Fluwx();
//   final InAppPurchase _iap = InAppPurchase.instance;
//   late StreamSubscription<List<PurchaseDetails>> subscription;
//   var subOrderNoString = "".obs;
//   @override
//   void onInit() {
//     super.onInit();
//     initVipPackage();
//     final purchaseUpdated = _iap.purchaseStream;
//     subscription = purchaseUpdated.listen(_onPurchaseUpdated);
//   }

 

//   Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
//     try {
//       for (final purchase in purchases) {
//         if (purchase.status == PurchaseStatus.purchased) {
//           // 成功购买，验证收据、发放商品
//           _iap.completePurchase(purchase);
//           OrderVerifyTransactionModel orderVerify = OrderVerifyTransactionModel(
//             transactionId: purchase.purchaseID,
//             subOrderNo: subOrderNoString.value,
//             customerId: appController.userInfo.value.id,
//           );
//           await PaymentService.verifyReceipt(orderVerify).then((val) async {
//             if (val) {
//               await PersonalService.getCurrentUserLoginInfo().then((user) {
//                 if (user != null) {
//                   appController.userInfo.value = user;
//                 }
//               });
//             }
//           }); //将Apple 内购成功的ID传给后端验证
//         } else if (purchase.status == PurchaseStatus.error) {
//           // ✅ 处理用户取消
//           if (purchase.error?.code == 'userCancelled') {
//             print('用户取消了购买');
//           } else {
//             print('购买失败: ${purchase.error}');
//           }
//         }
//       }
//     } catch (erroe) {
//       print('用户取消了购买');
//     }
//   }

//   Future<void> playOrderByProduct({required String productId}) async {
//     await EasyLoading.show();
//     Set<String> ids = {productId};
//     ProductDetailsResponse response = await _iap.queryProductDetails(ids);
//     if (response.notFoundIDs.isNotEmpty) {
//       // 找不到商品
//     } else {
//       ProductDetails product = response.productDetails.first;
//       try {
//         subOrderNoString.value = "";
//         OrderCreateModel order = OrderCreateModel(
//           appleProductId: product.id, //订单编号
//         );
//         await PaymentService.createOrder(order).then((val) {
//           if (val != null) {
//             subOrderNoString.value = val.subOrderNo!;
//           }
//         });
//         final purchaseParam = PurchaseParam(productDetails: product);
//         _iap.buyConsumable(purchaseParam: purchaseParam);
//       } catch (error) {
//         print("取消订单");
//       }
//     }
//     await EasyLoading.dismiss();
//   }

//   String transData(double transMinute) {
//     if (transMinute.toString().contains(".")) {
//       var data = transMinute.toString().split(".");
//       if (data.last == "0") {
//         return data.first;
//       }
//     }
//     return transMinute.toString();
//   }

//   void play(VIPackageModel pack) {
//     if (PermissionsHelper.isIOS()) {
//       //苹果内购
//       if (pack.productId != null) {
//         playOrderByProduct(productId: pack.productId!);
//       }
//     } else {
//       //微信支付
//     }
//   }

//   Future<void> unlock() async {}

//   String calculateDayPrice(double? monthlyPrice) {
//     String dayPrice = "";
//     if (monthlyPrice != null) {
//       if (monthOrYear.value == 0) {
//         dayPrice = (monthlyPrice / 30).toStringAsFixed(2);
//       } else {
//         dayPrice = (monthlyPrice / 365).toStringAsFixed(2);
//       }
//       return dayPrice;
//     } else {
//       return "--";
//     }
//   }

//   String transByteToG(int? byte) {
//     if (byte != null) {
//       return (byte / 1073741824).toStringAsFixed(2);
//     } else {
//       return "--";
//     }
//   }

//   // void createPlay({
//   //   required String price,
//   //   required String monthOrYearType,
//   //   required String vipType,
//   //   required String platPayWayString,
//   // }) {
//   //   String prepayId = '你的预支付ID'; // 从服务器获取的预支付ID
//   //   String partnerId = '你的商户号'; // 通常与mchId相同，但这里为了示例分开写明
//   //   var packageValue = price; // 固定值
//   //   String nonceStr = '随机字符串'; // 随机生成的字符串，用于签名等操作
//   //   var timeStamp = DateTime.now().millisecondsSinceEpoch; // 时间戳，通常是当前时间的秒数
//   //   String paySign = '签名'; // 使用API密钥和上述参数生成的签名

//   //   OrderCreateModel order = OrderCreateModel(
//   //     packageType: vipType, //套餐类型
//   //     paymentPeriod: monthOrYearType,
//   //   );
//   //   PaymentService.createOrder(order).then((val) {
//   //     if (val != null && val.subOrderNo != null) {
//   //       String payPlatFormString = "";
//   //       String platPayWayString = "";
//   //       if (PermissionsHelper.isIOS()) {
//   //         //苹果支付
//   //         payPlatFormString = "APPLE_APP";
//   //         platPayWayString = "APPLE_APP";
//   //       } else {
//   //         //微信支付
//   //         payPlatFormString = "WECHAT";
//   //         platPayWayString = "WX_APP";
//   //       }
//   //       PayRequestModel pay = PayRequestModel(
//   //         subOrderNo: val.subOrderNo!,
//   //         payPlatform: payPlatFormString,
//   //         platPayWay: platPayWayString,
//   //       );
//   //       PaymentService.payRequest(pay).then((val) {
//   //         if (val != null && val.data != null) {
//   //           DialogHelper.showQr(val.data);
//   //         } else {
//   //           DialogHelper.showToastDialog("支付失败");
//   //         }
//   //       });
//   //     }
//   //   });

//   //   //微信支付
//   //   // try {
//   //   //   fluwx.pay(
//   //   //     which: Payment(
//   //   //       appId: Config.appId,
//   //   //       partnerId: partnerId,
//   //   //       prepayId: prepayId,
//   //   //       packageValue: packageValue,
//   //   //       nonceStr: nonceStr,
//   //   //       timestamp: timeStamp,
//   //   //       sign: paySign,
//   //   //     ),
//   //   //   );
//   //   //   print('支付成功');
//   //   // } catch (e) {
//   //   //   print('支付失败: $e');
//   //   // }
//   // }

//   // String transPackageProductName(String productTitle) {
//   //   if (productTitle.contains("-")) {
//   //     var data = productTitle.split("-");
//   //     return data.first;
//   //   }
//   //   return "--";
//   // }

//   // String dayPriceByPackage(String productPrice) {
//   //   if (productPrice.contains("¥")) {
//   //     productPrice = productPrice.substring(1);
//   //   }

//   //   var pricr = double.parse(productPrice);
//   //   var dayPrice = pricr / 30;

//   //   return dayPrice.toStringAsFixed(2);
//   // }

//   // String priceBySub(String productPrice) {
//   //   if (productPrice.contains("¥")) {
//   //     productPrice = productPrice.substring(1);
//   //   }
//   //   return productPrice;
//   // }
// }

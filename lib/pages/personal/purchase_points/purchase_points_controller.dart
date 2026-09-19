import 'dart:async';
import 'dart:io';

import 'package:dting/model/payment/order_pay_model.dart';
import 'package:dting/model/payment/order_verify_transaction_model.dart';
import 'package:dting/model/payment/pay_model.dart';
import 'package:dting/model/teams_model/point_package_model.dart';
import 'package:dting/service/personal_service.dart';
import 'package:dting/service/point_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/permission_helper.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:fluwx/fluwx.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

class PurchasePointsController extends GetxController {
  var appController = Get.find<DtingStore>();
  var selectPackage = PointPackageModel.genDefault().obs; //当前选中的权益

  //支付
  Fluwx fluwx = Fluwx();
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> subscription; // 苹果支付的流订阅
  var subOrderNoString = "".obs; // 订单编号
  var wechatSubscription; // 存储微信支付的订阅

  @override
  void onInit() {
    super.onInit();

    _initInAppPurchase();

    initPointPackageList();
    // 监听支付结果
    // 注册微信回调监听
    wechatSubscription = fluwx.addSubscriber((response) async {
      if (response is WeChatPaymentResponse) {
        if (response.errCode == 0) {
          print("支付成功");
          DialogHelper.showToastDialog("paySuccessful");
          PersonalService.getCurrentUserLoginInfo().then((user) {
            if (user != null) {
              appController.userInfo.value = user;
            }
          });
        } else {
          print("支付失败：${response.errStr}");
          DialogHelper.showToastDialog("payFail");
        }
      }
    });

    //注册苹果支付回调
    subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onDone: () {
        subscription.cancel();
      },
      onError: (error) {
        print("IAP purchaseStream error: $error");
        DialogHelper.showToastDialog("payFail");
      },
    );
  }

  Future<void> _initInAppPurchase() async {
    if (await InAppPurchase.instance.isAvailable()) {
      if (Platform.isIOS) {
        final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
            InAppPurchase.instance
                .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
        await iosPlatformAddition.setDelegate(DtingInPaymentQueueDelegate());
      }
    }
  }

  //获取积分套餐
  void initPointPackageList() {
    if (appController.pointPackageList.isEmpty) {
      PointService.getPointPackageList().then((val) {
        appController.pointPackageList.value = val;
        appController.personalPointPackageList.value =
            val.where((package) => package.pointsPackageType == "P").toList();
        appController.teamPointPackageList.value =
            val.where((package) => package.pointsPackageType == "T").toList();
        selectPackage.value = appController.personalPointPackageList.first;
      });
    } else {
      selectPackage.value = appController.personalPointPackageList.first;
    }
  }

  //购买积分
  Future<void> purchasePointPay() async {
    if (selectPackage.value.pointsPackageCode.isEmpty) {
      DialogHelper.showToastDialog("selectPackage");
      return;
    }
    if (PermissionsHelper.isIOS()) {
      // 苹果内购
      payOrderByProduct();
    } else {
      // 微信支付
      var installWechat = await fluwx.isWeChatInstalled;
      if (!installWechat) {
        DialogHelper.showToastDialog("wechatTip");
        return;
      }
      payByWechat();
    }
  }

  //苹果支付
  payOrderByProduct() async {
    final bool available = await InAppPurchase.instance.isAvailable();
    print("IAP Available: $available"); // 如果是 false，永远不会弹出
    ProductDetailsResponse response = await _iap.queryProductDetails({
      selectPackage.value.pointsPackageCode,
    });
    if (response.notFoundIDs.isNotEmpty) {
      // 找不到商品
      DialogHelper.showToastDialog("payFail");
    } else {
      ProductDetails product = response.productDetails.first;
      try {
        await EasyLoading.show();
        //创建业务订单
        var order = await PointService.createOrder(
          productCode: selectPackage.value.pointsPackageCode,
          productType: 'PERSONAL_POINT',
        );
        if (order == null) {
          await EasyLoading.dismiss();
          DialogHelper.showToastDialog("payFail");
          return;
        }

        //创建支付订单
        // PayRequestModel request = PayRequestModel(
        //   orderNo: order.orderNo,
        //   payPlatform: 'APPLE_PAY',
        //   platPayWay: "APPLE_PAY",
        // );
        subOrderNoString.value = order.orderNo;

        // 补:支付接口的调用（苹果内购后端自动调了支付接口）
        // final payRequest = await PointService.payRequest(request);
        // if (payRequest == null || payRequest.code != 200) {
        //   await EasyLoading.dismiss();
        //   DialogHelper.showToastDialog(payRequest?.msg ?? "payFail");
        //   return;
        // }

        //内购唤起
        final purchaseParam = PurchaseParam(productDetails: product);
        await _iap.buyConsumable(purchaseParam: purchaseParam);
      } catch (error) {
        print("取消订单: $error");
        // 用户取消支付时，重置订单号
        subOrderNoString.value = "";
      } finally {
        await EasyLoading.dismiss();
      }
    }
  }

  @override
  void onClose() {
    super.onClose();
    // 控制器销毁时，确保清理状态
    subOrderNoString.value = "";

    // 取消苹果支付的流订阅
    subscription.cancel();

    // 取消微信支付的回调订阅
    if (wechatSubscription != null) {
      fluwx.removeSubscriber(wechatSubscription);
    }
  }

  //苹果内购回调
  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    try {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.error) {
          // ✅ 处理用户取消或错误
          if (purchase.error?.code == 'userCancelled') {
            print('用户取消了购买');
            DialogHelper.showToastDialog("cancelPay");
          } else {
            print('购买失败: ${purchase.error}');
            DialogHelper.showToastDialog("payFail");
          }
          // 无论成功失败，都需要完成交易，防止交易缓存
          _iap.completePurchase(purchase);
          // 重置订单号
          subOrderNoString.value = "";
          return;
        }

        if (purchase.status == PurchaseStatus.canceled) {
          print('用户取消了购买');
          DialogHelper.showToastDialog("cancelPay");
          // 无论成功失败，都需要完成交易，防止交易缓存
          _iap.completePurchase(purchase);
          // 重置订单号
          subOrderNoString.value = "";
          return;
        }

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          // 成功购买，验证收据、发放商品
          _iap.completePurchase(purchase);
          if (purchase.purchaseID != null &&
              subOrderNoString.value.isNotEmpty) {
            OrderVerifyTransactionModel orderVerify =
                OrderVerifyTransactionModel(
                  transactionId: purchase.purchaseID!,
                  orderNo: subOrderNoString.value,
                  receipt: purchase.verificationData.serverVerificationData,
                );
            await PointService.verifyReceipt(orderVerify).then((val) async {
              if (val) {
                await PersonalService.getCurrentUserLoginInfo().then((user) {
                  if (user != null) {
                    appController.userInfo.value = user;
                    DialogHelper.showToastDialog("paySuccessful");
                  }
                });
              }
            }); //将Apple 内购成功的ID传给后端验证
          }
          // 购买完成后重置订单号
          subOrderNoString.value = "";
        }
        // 如果购买状态是 pending，可以根据需要添加处理逻辑
        if (purchase.status == PurchaseStatus.pending) {
          print('购买处理中');
        }
      }
    } catch (error) {
      print('处理购买时发生错误: $error');
      DialogHelper.showToastDialog("payFail");
    }
  }

  //微信支付
  Future<void> payByWechat() async {
    //微信支付
    //TEAM_POINT
    // PERSONAL_POINT
    // TEAM_SEAT
    await EasyLoading.show();

    try {
      var order = await PointService.createOrder(
        productCode: selectPackage.value.pointsPackageCode,
        productType: 'PERSONAL_POINT',
      );
      if (order == null) {
        await EasyLoading.dismiss();
        DialogHelper.showToastDialog("payFail");
        return;
      }
      PayRequestModel request = PayRequestModel(
        orderNo: order.orderNo,
        payPlatform: 'WECHAT', //ALIPAY 、WECHAT 、 APPLE
        platPayWay:
            "WX_APP", //WX_APP - 微信APP支付、ALI_APP - 支付宝APP、支付APPLE_APP - 苹果支付
      );

      var payRequest = await PointService.payRequest(request);
      if (payRequest == null) {
        await EasyLoading.dismiss();
        DialogHelper.showToastDialog("payFail");
        return;
      }
      if (payRequest.code != 200) {
        var message = payRequest.msg;
        DialogHelper.showToastDialog(message);
        return;
      }

      var returnData = OrderPayResponseModel.fromJson(payRequest.data);

      fluwx.pay(
        which: Payment(
          appId: returnData.appid!,
          partnerId: returnData.partnerid!,
          prepayId: returnData.prepayid!, //预支付交易会话 ID
          packageValue: "Sign=WXPay",
          nonceStr: returnData.noncestr!,
          timestamp: int.parse(returnData.timestamp!),
          sign: returnData.sign!, //预签名
        ),
      );
      await EasyLoading.dismiss();
    } catch (e) {
      print('支付失败: $e');
    }
  }
}

class DtingInPaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}

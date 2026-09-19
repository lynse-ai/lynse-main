import 'dart:async';
import 'dart:io';

import 'package:dting/model/payment/order_pay_model.dart';
import 'package:dting/model/payment/order_verify_transaction_model.dart';
import 'package:dting/model/payment/pay_model.dart';
import 'package:dting/model/teams_model/point_package_model.dart';
import 'package:dting/pages/personal/purchase_points/purchase_points_controller.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/service/point_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/permission_helper.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:fluwx/fluwx.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

class TeamPurchasePointsController extends GetxController {
  var appController = Get.find<DtingStore>();
  var teamFileController = Get.find<TeamFileController>();

  var selectPackage = PointPackageModel.genDefault().obs; //当前选中的权益
  Fluwx fluwx = Fluwx();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> subscription;
  var subOrderNoString = "".obs; //订单编号
  @override
  void onInit() {
    super.onInit();

    _initInAppPurchase();
    initPointPackageList();
    // 监听支付结果
    // 注册微信回调监听（全局只注册一次）
    fluwx.addSubscriber((response) async {
      if (response is WeChatPaymentResponse) {
        if (response.errCode == 0) {
          print("支付成功");
          DialogHelper.showToastDialog("paySuccessful");
          teamFileController.getCurrentTeamDetail();
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

  //苹果支付回调
  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    try {
      for (final purchase in purchases) {
        if (purchase.status == PurchaseStatus.error) {
          // ✅ 处理用户取消
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

        if (purchase.status == PurchaseStatus.purchased) {
          // 成功购买，验证收据、发放商品
          _iap.completePurchase(purchase);
          OrderVerifyTransactionModel orderVerify = OrderVerifyTransactionModel(
            transactionId: purchase.purchaseID!,
            orderNo: subOrderNoString.value,
            receipt: purchase.verificationData.serverVerificationData,
          );
          await PointService.verifyReceipt(orderVerify).then((val) async {
            //刷新团队积分
            if (!val) {
              DialogHelper.showToastDialog("payFail");
              return;
            }
            teamFileController.getCurrentTeamDetail();
            return;
          }); //将Apple 内购成功的ID传给后端验证
        }
      }
    } catch (erroe) {
      print('用户取消了购买');
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
        selectPackage.value = appController.teamPointPackageList.first;
      });
    } else {
      selectPackage.value = appController.teamPointPackageList.first;
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
          productType: 'TEAM_POINT',
          teamId: teamFileController.currentTeam.value.id,
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
        // var payRequest = await PointService.payRequest(request);
        // if (payRequest != null && payRequest.code == 200) {
        // subOrderNoString.value = payRequest.data["appAccountToken"];
        //内购唤起
        final purchaseParam = PurchaseParam(productDetails: product);
        _iap.buyConsumable(purchaseParam: purchaseParam);
        // } else {
        //   DialogHelper.showToastDialog("payFail");
        // }
      } catch (error) {
        print("取消订单");
      } finally {
        await EasyLoading.dismiss();
      }
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
        productType: 'TEAM_POINT',
        teamId: teamFileController.currentTeam.value.id,
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
        await EasyLoading.dismiss();
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

import 'package:dting/http/http_helper.dart';
import 'package:dting/model/baseapi/response_api_model.dart';
import 'package:dting/model/payment/order_notify_model.dart';
import 'package:dting/model/payment/order_verify_transaction_model.dart';
import 'package:dting/model/payment/pay_notify_model.dart';
import 'package:dting/model/payment/pay_model.dart';
import 'package:dting/model/payment/point_history_log.dart';
import 'package:dting/model/payment/response_order_create_model.dart';
import 'package:dting/model/teams_model/point_package_model.dart';
import 'package:dting/model/teams_model/seat_package_model.dart';
import 'package:get/get.dart';

class PointService {
  PointService._();

  //积分套餐获取
  static Future<List<PointPackageModel>> getPointPackageList() async {
    List<PointPackageModel> returnData = [];

    await HttpHelper.get('/api/pay/points/list').then((value) {
      if (value != null && value.code == 200 && value.data != null) {
        if(GetPlatform.isIOS){
          returnData = List<PointPackageModel>.from(
            value.data.map((x) => PointPackageModel.fromJson(x)),
          ).where((package) => package.channel == 'APPLE').toList();
        }
        if(GetPlatform.isAndroid){
          returnData = List<PointPackageModel>.from(
            value.data.map((x) => PointPackageModel.fromJson(x)),
          ).where((package) => package.channel == 'WECHAT').toList();
        }
      }
    });
    return returnData;
  }

  //积分套餐详情
  static Future<PointPackageModel?> getPointPackageByPackageId({
    required String pointsPackageId,
  }) async {
    PointPackageModel? returnData;

    await HttpHelper.get('/api/pay/points/$pointsPackageId').then((value) {
      if (value != null && value.code == 200 && value.data != null) {
        returnData = PointPackageModel.fromJson(value.data);
      }
    });
    return returnData;
  }

  //席位套餐获取
  static Future<List<SeatPackageModel>> geSeatPackageList() async {
    List<SeatPackageModel> returnData = [];

    await HttpHelper.get('/api/pay/seat/list').then((value) {
      if (value != null && value.code == 200 && value.data != null) {
        returnData = List<SeatPackageModel>.from(
          value.data.map((x) => SeatPackageModel.fromJson(x)),
        );
      }
    });
    return returnData;
  }

  //席位套餐详情
  static Future<SeatPackageModel?> getSeatPackageByPackageId({
    required String teamSeatPackageId,
  }) async {
    SeatPackageModel? returnData;

    await HttpHelper.get('/api/pay/seat/$teamSeatPackageId').then((value) {
      if (value != null && value.code == 200 && value.data != null) {
        returnData = SeatPackageModel.fromJson(value.data);
      }
    });
    return returnData;
  }

  //苹果支付
  static Future<ResponseApiModel?> getPayNotify(
    PayNotifyModel applePlay,
  ) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/pay/notify/apple',
      data: {
        "tenantId": applePlay.tenantId,
        "orderNo": applePlay.orderNo,
        "subOrderNo": applePlay.subOrderNo,
        "payPlatform": applePlay.payPlatform,
        "platPayWay": applePlay.platPayWay,
        "providerId": applePlay.providerId,
        "merchantId": applePlay.merchantId,
        "status": applePlay.status,
        "receipt": applePlay.receipt,
        "chooseEnv": applePlay.chooseEnv,
        "customerId": applePlay.customerId,
      },
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  //支付成功回调
  static Future<bool> verifyReceipt(
    OrderVerifyTransactionModel orderVerify,
  ) async {
    bool returnData = false;

    await HttpHelper.post(
      '/api/pay/apple/verifyTransaction',
      data: {
        "receipt": orderVerify.receipt,
        "chooseEnv": orderVerify.chooseEnv,
        'transactionId': orderVerify.transactionId,
        "orderNo": orderVerify.orderNo,
      },
    ).then((value) {
      if (value != null && value.data != null) {
        returnData = value.data;
      }
    });
    return returnData;
  }

  //创建业务订单
  static Future<ResponseOrderCreateModel?> createOrder({
    required String productCode,
    required String productType,
    String? teamId,
  }) async {
    ResponseOrderCreateModel? returnData;

    await HttpHelper.post(
      '/api/pay/order/create',
      data: {
        "productCode": productCode,
        "productType": productType,
        "teamId": teamId,
      },
    ).then((value) {
      if (value != null && value.data != null) {
        returnData = ResponseOrderCreateModel.fromJson(value.data);
      }
    });

    return returnData;
  }

  //创建支付订单
  static Future<ResponseApiModel?> payRequest(PayRequestModel pay) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/pay/order/pay',
      data: {
        "orderNo": pay.orderNo,
        "payPlatform": pay.payPlatform,
        "platPayWay": pay.platPayWay,
        "openId": pay.openId,
      },
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  //取消订单
  static Future<ResponseApiModel?> cancelPay({
    required String orderNo,
    String? canceledReason,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/pay/order/cancel',
      data: {"orderNo": orderNo, "canceledReason": canceledReason},
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  //通知业务订单
  static Future<ResponseApiModel?> notify(OrderNotifyModel notify) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/pay/order/notify',
      data: {
        "tenantId": notify.tenantId,
        "orderNo": notify.orderNo,
        "payPlatform": notify.payPlatform,
        "platPayWay": notify.platPayWay,
        "providerId": notify.providerId,
        "merchantId": notify.merchantId,
        "status": notify.status,
      },
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  //微信支付
  static Future<ResponseApiModel?> wechat(OrderNotifyModel notify) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/pay/notify/wechat',
      data: {
        "tenantId": notify.tenantId,
        "orderNo": notify.orderNo,
        "payPlatform": notify.payPlatform,
        "platPayWay": notify.platPayWay,
        "providerId": notify.providerId,
        "merchantId": notify.merchantId,
        "status": notify.status,
      },
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  //积分流水记录
  static Future<List<PointHisToryLogModel>> queryPointsLog({
    required String pointsLogType,
    String? teamId,
    int? pageSize,
    int? pageNum,
  }) async {
    List<PointHisToryLogModel> returnData = [];

    await HttpHelper.get(
      '/api/business/pointsLog/queryPointsLog',
      queryParameters: {
        "pointsLogType": pointsLogType,
        "teamId": teamId,
        "pageSize": pageSize,
        "pageNum": pageNum,
      },
    ).then((value) {
      if (value != null && value.code == 200 && value.data != null) {
        returnData = List<PointHisToryLogModel>.from(
          value.data.map((x) => PointHisToryLogModel.fromJson(x)),
        );
      }
    });

    return returnData;
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pay_notify_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PayNotifyModel _$PayNotifyModelFromJson(Map<String, dynamic> json) =>
    PayNotifyModel(
      tenantId: json['tenantId'] as String?,
      orderNo: json['orderNo'] as String?,
      subOrderNo: json['subOrderNo'] as String?,
      payPlatform: json['payPlatform'] as String?,
      platPayWay: json['platPayWay'] as String?,
      providerId: json['providerId'] as String?,
      merchantId: json['merchantId'] as String?,
      status: json['status'] as String?,
      receipt: json['receipt'] as String,
      chooseEnv: json['chooseEnv'] as String?,
      customerId: json['customerId'] as String?,
    );

Map<String, dynamic> _$PayNotifyModelToJson(PayNotifyModel instance) =>
    <String, dynamic>{
      'tenantId': instance.tenantId,
      'orderNo': instance.orderNo,
      'subOrderNo': instance.subOrderNo,
      'payPlatform': instance.payPlatform,
      'platPayWay': instance.platPayWay,
      'providerId': instance.providerId,
      'merchantId': instance.merchantId,
      'status': instance.status,
      'receipt': instance.receipt,
      'chooseEnv': instance.chooseEnv,
      'customerId': instance.customerId,
    };

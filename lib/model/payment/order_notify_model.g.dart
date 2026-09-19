// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_notify_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderNotifyModel _$OrderNotifyModelFromJson(Map<String, dynamic> json) =>
    OrderNotifyModel(
      tenantId: json['tenantId'] as String?,
      orderNo: json['orderNo'] as String?,
      payPlatform: json['payPlatform'] as String?,
      platPayWay: json['platPayWay'] as String?,
      providerId: json['providerId'] as String?,
      merchantId: json['merchantId'] as String?,
      status: json['status'] as String?,
    );

Map<String, dynamic> _$OrderNotifyModelToJson(OrderNotifyModel instance) =>
    <String, dynamic>{
      'tenantId': instance.tenantId,
      'orderNo': instance.orderNo,
      'payPlatform': instance.payPlatform,
      'platPayWay': instance.platPayWay,
      'providerId': instance.providerId,
      'merchantId': instance.merchantId,
      'status': instance.status,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pay_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PayRequestModel _$PayRequestModelFromJson(Map<String, dynamic> json) =>
    PayRequestModel(
      orderNo: json['orderNo'] as String,
      payPlatform: json['payPlatform'] as String,
      platPayWay: json['platPayWay'] as String?,
      openId: json['openId'] as String?,
    );

Map<String, dynamic> _$PayRequestModelToJson(PayRequestModel instance) =>
    <String, dynamic>{
      'orderNo': instance.orderNo,
      'payPlatform': instance.payPlatform,
      'platPayWay': instance.platPayWay,
      'openId': instance.openId,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_pay_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderPayResponseModel _$OrderPayResponseModelFromJson(
  Map<String, dynamic> json,
) => OrderPayResponseModel(
  timestamp: json['timestamp'] as String?,
  prepayid: json['prepayid'] as String?,
  sign: json['sign'] as String?,
  noncestr: json['noncestr'] as String?,
  appid: json['appid'] as String?,
  partnerid: json['partnerid'] as String?,
);

Map<String, dynamic> _$OrderPayResponseModelToJson(
  OrderPayResponseModel instance,
) => <String, dynamic>{
  'timestamp': instance.timestamp,
  'prepayid': instance.prepayid,
  'sign': instance.sign,
  'noncestr': instance.noncestr,
  'appid': instance.appid,
  'partnerid': instance.partnerid,
};

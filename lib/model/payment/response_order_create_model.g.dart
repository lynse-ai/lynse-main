// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'response_order_create_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResponseOrderCreateModel _$ResponseOrderCreateModelFromJson(
  Map<String, dynamic> json,
) => ResponseOrderCreateModel(
  orderNo: json['orderNo'] as String,
  fee: (json['fee'] as num?)?.toDouble(),
);

Map<String, dynamic> _$ResponseOrderCreateModelToJson(
  ResponseOrderCreateModel instance,
) => <String, dynamic>{'orderNo': instance.orderNo, 'fee': instance.fee};

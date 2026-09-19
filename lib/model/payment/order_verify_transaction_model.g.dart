// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_verify_transaction_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderVerifyTransactionModel _$OrderVerifyTransactionModelFromJson(
  Map<String, dynamic> json,
) => OrderVerifyTransactionModel(
  chooseEnv: json['chooseEnv'] as bool?,
  transactionId: json['transactionId'] as String,
  receipt: json['receipt'] as String?,
  orderNo: json['orderNo'] as String,
);

Map<String, dynamic> _$OrderVerifyTransactionModelToJson(
  OrderVerifyTransactionModel instance,
) => <String, dynamic>{
  'receipt': instance.receipt,
  'chooseEnv': instance.chooseEnv,
  'transactionId': instance.transactionId,
  'orderNo': instance.orderNo,
};

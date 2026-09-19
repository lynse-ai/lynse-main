// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verificationcode_sms_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VerificationCodeBySMSModel _$VerificationCodeBySMSModelFromJson(
  Map<String, dynamic> json,
) => VerificationCodeBySMSModel(
  phone: json['phone'] as String,
  actionType: json['actionType'] as String,
);

Map<String, dynamic> _$VerificationCodeBySMSModelToJson(
  VerificationCodeBySMSModel instance,
) => <String, dynamic>{
  'phone': instance.phone,
  'actionType': instance.actionType,
};

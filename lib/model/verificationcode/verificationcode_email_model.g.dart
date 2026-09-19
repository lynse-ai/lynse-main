// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verificationcode_email_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VerificationCodeByEmailModel _$VerificationCodeByEmailModelFromJson(
  Map<String, dynamic> json,
) => VerificationCodeByEmailModel(
  email: json['email'] as String,
  actionType: json['actionType'] as String,
);

Map<String, dynamic> _$VerificationCodeByEmailModelToJson(
  VerificationCodeByEmailModel instance,
) => <String, dynamic>{
  'email': instance.email,
  'actionType': instance.actionType,
};

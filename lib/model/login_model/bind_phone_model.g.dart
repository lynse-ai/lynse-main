// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bind_phone_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BindPhoneModel _$BindPhoneModelFromJson(Map<String, dynamic> json) =>
    BindPhoneModel(
      authType: json['authType'] as String,
      username: json['username'] as String,
      thirdPartyId: json['thirdPartyId'] as String,
      captchaCode: json['captchaCode'] as String,
    );

Map<String, dynamic> _$BindPhoneModelToJson(BindPhoneModel instance) =>
    <String, dynamic>{
      'authType': instance.authType,
      'username': instance.username,
      'thirdPartyId': instance.thirdPartyId,
      'captchaCode': instance.captchaCode,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginRequestModel _$LoginRequestModelFromJson(Map<String, dynamic> json) =>
    LoginRequestModel(
      authType: json['authType'] as String,
      username: json['username'] as String?,
      password: json['password'] as String?,
      code: json['code'] as String?,
      state: json['state'] as String?,
      deviceType: json['deviceType'] as String?,
      captchaEnable: json['captchaEnable'] as bool?,
      identityToken: json['identityToken'] as String?,
      captchaCode: json['captchaCode'] as String?,
    );

Map<String, dynamic> _$LoginRequestModelToJson(LoginRequestModel instance) =>
    <String, dynamic>{
      'authType': instance.authType,
      'username': instance.username,
      'password': instance.password,
      'code': instance.code,
      'state': instance.state,
      'deviceType': instance.deviceType,
      'captchaEnable': instance.captchaEnable,
      'identityToken': instance.identityToken,
      'captchaCode': instance.captchaCode,
    };

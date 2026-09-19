// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegisterRequestModel _$RegisterRequestModelFromJson(
  Map<String, dynamic> json,
) => RegisterRequestModel(
  confirmPassword: json['confirmPassword'] as String,
  captchaCode: json['captchaCode'] as String,
  username: json['username'] as String,
  password: json['password'] as String,
);

Map<String, dynamic> _$RegisterRequestModelToJson(
  RegisterRequestModel instance,
) => <String, dynamic>{
  'confirmPassword': instance.confirmPassword,
  'username': instance.username,
  'password': instance.password,
  'captchaCode': instance.captchaCode,
};

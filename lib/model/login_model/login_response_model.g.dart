// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_response_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginResponsetModel _$LoginResponsetModelFromJson(Map<String, dynamic> json) =>
    LoginResponsetModel(
      token: json['token'] as String?,
      openId: json['openId'] as String?,
      firstLogin: json['firstLogin'] as bool?,
      customerId: json['customerId'] as String?,
      thirdPartyId: json['thirdPartyId'] as String?,
      needBind: json['needBind'] as bool?,
      expireIn: (json['expireIn'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LoginResponsetModelToJson(
  LoginResponsetModel instance,
) => <String, dynamic>{
  'token': instance.token,
  'expireIn': instance.expireIn,
  'firstLogin': instance.firstLogin,
  'needBind': instance.needBind,
  'openId': instance.openId,
  'customerId': instance.customerId,
  'thirdPartyId': instance.thirdPartyId,
};

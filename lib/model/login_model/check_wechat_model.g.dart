// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_wechat_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CheckWechatModel _$CheckWechatModelFromJson(Map<String, dynamic> json) =>
    CheckWechatModel(
      signature: json['signature'] as String,
      timestamp: json['timestamp'] as String,
      nonce: json['nonce'] as String,
      echostr: json['echostr'] as String,
    );

Map<String, dynamic> _$CheckWechatModelToJson(CheckWechatModel instance) =>
    <String, dynamic>{
      'signature': instance.signature,
      'timestamp': instance.timestamp,
      'nonce': instance.nonce,
      'echostr': instance.echostr,
    };

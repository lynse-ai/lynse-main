// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShareModel _$ShareModelFromJson(Map<String, dynamic> json) => ShareModel(
  sharerId: json['sharerId'] as String?,
  shareTime: json['shareTime'] as String?,
  expirationTime: json['expirationTime'] as String?,
  shareUrl: json['shareUrl'] as String?,
  shareTitle: json['shareTitle'] as String?,
  shareMessage: json['shareMessage'] as String?,
);

Map<String, dynamic> _$ShareModelToJson(ShareModel instance) =>
    <String, dynamic>{
      'sharerId': instance.sharerId,
      'shareTime': instance.shareTime,
      'expirationTime': instance.expirationTime,
      'shareUrl': instance.shareUrl,
      'shareTitle': instance.shareTitle,
      'shareMessage': instance.shareMessage,
    };

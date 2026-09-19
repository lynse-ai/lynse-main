// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ota_version_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtaVersionModel _$OtaVersionModelFromJson(Map<String, dynamic> json) =>
    OtaVersionModel(
      json['id'] as String,
      $enumDecode(_$OtaVersionPlatformEnumMap, json['platform']),
      json['versionName'] as String,
      json['updateLog'] as String,
      json['ossUrl'] as String,
      (json['forceUpdate'] as num).toInt(),
      json['filename'] as String,
      json['path'] as String?,
      json['contentType'] as String?,
    );

Map<String, dynamic> _$OtaVersionModelToJson(OtaVersionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'platform': _$OtaVersionPlatformEnumMap[instance.platform]!,
      'versionName': instance.versionName,
      'updateLog': instance.updateLog,
      'ossUrl': instance.ossUrl,
      'forceUpdate': instance.forceUpdate,
      'filename': instance.filename,
      'path': instance.path,
      'contentType': instance.contentType,
    };

const _$OtaVersionPlatformEnumMap = {
  OtaVersionPlatform.android: 'android',
  OtaVersionPlatform.ios: 'ios',
};

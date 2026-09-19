// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ota_firmware_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtaFirmwareModel _$OtaFirmwareModelFromJson(Map<String, dynamic> json) =>
    OtaFirmwareModel(
      json['version'] as String,
      json['url'] as String,
      json['path'] as String,
      json['name'] as String,
    );

Map<String, dynamic> _$OtaFirmwareModelToJson(OtaFirmwareModel instance) =>
    <String, dynamic>{
      'version': instance.version,
      'url': instance.url,
      'path': instance.path,
      'name': instance.name,
    };

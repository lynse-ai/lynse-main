// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connect_device_files_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectDeviceFilesModel _$ConnectDeviceFilesModelFromJson(
  Map<String, dynamic> json,
) => ConnectDeviceFilesModel(
  sn: json['sn'] as String,
  size: json['size'] as String,
  endTimestamp: json['endTimestamp'] as String,
  startTimestamp: json['startTimestamp'] as String,
  name: json['name'] as String,
  scene: json['scene'] as String,
);

Map<String, dynamic> _$ConnectDeviceFilesModelToJson(
  ConnectDeviceFilesModel instance,
) => <String, dynamic>{
  'sn': instance.sn,
  'size': instance.size,
  'endTimestamp': instance.endTimestamp,
  'startTimestamp': instance.startTimestamp,
  'name': instance.name,
  'scene': instance.scene,
};

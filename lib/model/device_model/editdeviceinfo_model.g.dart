// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editdeviceinfo_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EditDeviceInfoModel _$EditDeviceInfoModelFromJson(Map<String, dynamic> json) =>
    EditDeviceInfoModel(
      deviceId: json['deviceId'] as String,
      name: json['name'] as String?,
      serialNumber: json['serialNumber'] as String?,
      storageCapacity: json['storageCapacity'] as String?,
      usedSpace: json['usedSpace'] as String?,
      version: json['version'] as String?,
    );

Map<String, dynamic> _$EditDeviceInfoModelToJson(
  EditDeviceInfoModel instance,
) => <String, dynamic>{
  'deviceId': instance.deviceId,
  'name': instance.name,
  'serialNumber': instance.serialNumber,
  'storageCapacity': instance.storageCapacity,
  'usedSpace': instance.usedSpace,
  'version': instance.version,
};

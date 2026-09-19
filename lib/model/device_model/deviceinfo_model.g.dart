// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deviceinfo_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceInfoModel _$DeviceInfoModelFromJson(Map<String, dynamic> json) =>
    DeviceInfoModel(
      id: json['id'] as String?,
      tenantId: json['tenantId'] as String?,
      createBy: json['createBy'] as String?,
      createTime: json['createTime'] as String?,
      updateBy: json['updateBy'] as String?,
      updateTime: json['updateTime'] as String?,
      deviceName: json['deviceName'] as String?,
      serialNumber: json['serialNumber'] as String?,
      macAddress: json['macAddress'] as String?,
      storageCapacity: json['storageCapacity'] as String?,
      usedSpace: json['usedSpace'] as String?,
      version: json['version'] as String?,
      bindStatus: (json['bindStatus'] as num?)?.toInt(),
      owner: json['owner'] as String?,
      caseBattery: json['caseBattery'] as String?,
    )..nickname = json['nickname'] as String?;

Map<String, dynamic> _$DeviceInfoModelToJson(DeviceInfoModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'createBy': instance.createBy,
      'createTime': instance.createTime,
      'updateBy': instance.updateBy,
      'updateTime': instance.updateTime,
      'deviceName': instance.deviceName,
      'serialNumber': instance.serialNumber,
      'macAddress': instance.macAddress,
      'storageCapacity': instance.storageCapacity,
      'usedSpace': instance.usedSpace,
      'version': instance.version,
      'bindStatus': instance.bindStatus,
      'owner': instance.owner,
      'caseBattery': instance.caseBattery,
      'nickname': instance.nickname,
    };

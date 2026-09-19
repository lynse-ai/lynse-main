// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_device_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchBindDeviceModel _$SearchBindDeviceModelFromJson(
  Map<String, dynamic> json,
) => SearchBindDeviceModel(
  macAddress: json['macAddress'] as String,
  bindStatus: (json['bindStatus'] as num).toInt(),
  isBoundByMe: (json['isBoundByMe'] as num).toInt(),
  phone: json['phone'] as String?,
);

Map<String, dynamic> _$SearchBindDeviceModelToJson(
  SearchBindDeviceModel instance,
) => <String, dynamic>{
  'macAddress': instance.macAddress,
  'bindStatus': instance.bindStatus,
  'isBoundByMe': instance.isBoundByMe,
  'phone': instance.phone,
};

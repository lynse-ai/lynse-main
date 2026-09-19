// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_file_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadFileModel _$UploadFileModelFromJson(Map<String, dynamic> json) =>
    UploadFileModel(
      customerId: json['customerId'] as String?,
      path: json['path'] as String?,
      saveFilename: json['saveFilename'] as String?,
      objectId: json['objectId'] as String?,
      objectType: json['objectType'] as String?,
      folderId: json['folderId'] as String?,
      macAddress: json['macAddress'] as String?,
      location: json['location'] as String?,
      bizDuration: (json['bizDuration'] as num?)?.toInt(),
      mode: json['mode'] as String?,
      fileSize: (json['fileSize'] as num?)?.toInt(),
      teamId: json['teamId'] as String?,
      recordStartTime: json['recordStartTime'] as String?,
      scene: (json['scene'] as num?)?.toInt(),
    );

Map<String, dynamic> _$UploadFileModelToJson(UploadFileModel instance) =>
    <String, dynamic>{
      'customerId': instance.customerId,
      'saveFilename': instance.saveFilename,
      'path': instance.path,
      'objectId': instance.objectId,
      'objectType': instance.objectType,
      'folderId': instance.folderId,
      'macAddress': instance.macAddress,
      'location': instance.location,
      'bizDuration': instance.bizDuration,
      'mode': instance.mode,
      'fileSize': instance.fileSize,
      'teamId': instance.teamId,
      'recordStartTime': instance.recordStartTime,
      'scene': instance.scene,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FolderInfo _$FolderInfoFromJson(Map<String, dynamic> json) => FolderInfo(
  id: json['id'] as String,
  tenantId: json['tenantId'] as String?,
  createBy: json['createBy'] as String?,
  createTime: json['createTime'] as String?,
  updateBy: json['updateBy'] as String?,
  updateTime: json['updateTime'] as String?,
  folderName: json['folderName'] as String?,
  color: json['color'] as String?,
);

Map<String, dynamic> _$FolderInfoToJson(FolderInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'createBy': instance.createBy,
      'createTime': instance.createTime,
      'updateBy': instance.updateBy,
      'updateTime': instance.updateTime,
      'folderName': instance.folderName,
      'color': instance.color,
    };

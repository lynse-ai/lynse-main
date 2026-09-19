// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'minmap_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MindMapModel _$MindMapModelFromJson(Map<String, dynamic> json) => MindMapModel(
  id: json['id'] as String?,
  tenantId: json['tenantId'] as String?,
  createBy: json['createBy'] as String?,
  createTime: json['createTime'] as String?,
  updateBy: json['updateBy'] as String?,
  updateTime: json['updateTime'] as String?,
  fileId: json['fileId'] as String?,
  mindMapText: json['mindMapText'] as String?,
);

Map<String, dynamic> _$MindMapModelToJson(MindMapModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'createBy': instance.createBy,
      'createTime': instance.createTime,
      'updateBy': instance.updateBy,
      'updateTime': instance.updateTime,
      'fileId': instance.fileId,
      'mindMapText': instance.mindMapText,
    };

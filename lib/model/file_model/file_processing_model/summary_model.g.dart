// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'summary_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SummaryModel _$SummaryModelFromJson(Map<String, dynamic> json) => SummaryModel(
  id: json['id'] as String?,
  tenantId: json['tenantId'] as String?,
  createBy: json['createBy'] as String?,
  createTime: json['createTime'] as String?,
  updateBy: json['updateBy'] as String?,
  updateTime: json['updateTime'] as String?,
  fileId: json['fileId'] as String?,
  conclusionText: json['conclusionText'] as String?,
  feedback: json['feedback'] as String?,
  taskId: json['taskId'] as String?,
  againTaskId: json['againTaskId'] as String?,
);

Map<String, dynamic> _$SummaryModelToJson(SummaryModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'createBy': instance.createBy,
      'createTime': instance.createTime,
      'updateBy': instance.updateBy,
      'updateTime': instance.updateTime,
      'fileId': instance.fileId,
      'conclusionText': instance.conclusionText,
      'feedback': instance.feedback,
      'taskId': instance.taskId,
      'againTaskId': instance.againTaskId,
    };

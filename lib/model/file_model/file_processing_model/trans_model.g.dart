// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trans_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TransModel _$TransModelFromJson(Map<String, dynamic> json) => TransModel(
  id: json['id'] as String?,
  tenantId: json['tenantId'] as String?,
  createBy: json['createBy'] as String?,
  createTime: json['createTime'] as String?,
  updateBy: json['updateBy'] as String?,
  updateTime: json['updateTime'] as String?,
  taskId: json['taskId'] as String?,
  beginTime: (json['beginTime'] as num?)?.toInt(),
  silenceDuration: (json['silenceDuration'] as num?)?.toInt(),
  speakerId: json['speakerId'] as String?,
  speakerName: json['speakerName'] as String?,
  endTime: (json['endTime'] as num?)?.toInt(),
  text: json['text'] as String?,
  beginTimeStr: json['beginTimeStr'] as String?,
  endTimeStr: json['endTimeStr'] as String?,
);

Map<String, dynamic> _$TransModelToJson(TransModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'createBy': instance.createBy,
      'createTime': instance.createTime,
      'updateBy': instance.updateBy,
      'updateTime': instance.updateTime,
      'taskId': instance.taskId,
      'beginTime': instance.beginTime,
      'silenceDuration': instance.silenceDuration,
      'speakerId': instance.speakerId,
      'speakerName': instance.speakerName,
      'endTime': instance.endTime,
      'text': instance.text,
      'beginTimeStr': instance.beginTimeStr,
      'endTimeStr': instance.endTimeStr,
    };

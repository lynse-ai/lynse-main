// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'point_history_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PointHisToryLogModel _$PointHisToryLogModelFromJson(
  Map<String, dynamic> json,
) => PointHisToryLogModel(
  id: json['id'] as String?,
  tenantId: json['tenantId'] as String?,
  createBy: json['createBy'] as String?,
  createTime: json['createTime'] as String?,
  teamId: json['teamId'] as String?,
  businessType: (json['businessType'] as num?)?.toInt(),
  pointsAmount: (json['pointsAmount'] as num?)?.toInt(),
  operationType: json['operationType'] as String?,
  operateTime: json['operateTime'] as String?,
  pointsLogType: json['pointsLogType'] as String?,
  changeType: (json['changeType'] as num?)?.toInt(),
  pointsDetails: json['pointsDetails'] as String?,
  nickname: json['nickname'] as String?,
);

Map<String, dynamic> _$PointHisToryLogModelToJson(
  PointHisToryLogModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenantId': instance.tenantId,
  'createBy': instance.createBy,
  'createTime': instance.createTime,
  'teamId': instance.teamId,
  'businessType': instance.businessType,
  'pointsAmount': instance.pointsAmount,
  'operationType': instance.operationType,
  'operateTime': instance.operateTime,
  'pointsLogType': instance.pointsLogType,
  'changeType': instance.changeType,
  'pointsDetails': instance.pointsDetails,
  'nickname': instance.nickname,
};

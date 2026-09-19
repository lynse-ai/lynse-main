// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ota_update_status_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtaUpdateStatusModel _$OtaUpdateStatusModelFromJson(
  Map<String, dynamic> json,
) => OtaUpdateStatusModel(
  OtaUpdateStatus.fromValue((json['status'] as num).toInt()),
  (json['progress'] as num).toInt(),
  (json['upgradedSize'] as num).toInt(),
  json['error'] as String?,
);

Map<String, dynamic> _$OtaUpdateStatusModelToJson(
  OtaUpdateStatusModel instance,
) => <String, dynamic>{
  'status': _$OtaUpdateStatusEnumMap[instance.status]!,
  'progress': instance.progress,
  'upgradedSize': instance.upgradedSize,
  'error': instance.error,
};

const _$OtaUpdateStatusEnumMap = {
  OtaUpdateStatus.init: 'init',
  OtaUpdateStatus.progress: 'progress',
  OtaUpdateStatus.success: 'success',
  OtaUpdateStatus.failed: 'failed',
};

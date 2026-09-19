// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quota_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuotaModel _$QuotaModelFromJson(Map<String, dynamic> json) => QuotaModel(
  customerId: json['customerId'] as String?,
  quatoType: json['quatoType'] as String?,
  packageType: json['packageType'] as String?,
  addCloudStorageQuotaByte: (json['addCloudStorageQuotaByte'] as num?)?.toInt(),
  addTranscriptionMinutesQuota:
      (json['addTranscriptionMinutesQuota'] as num?)?.toInt(),
  addPlanDuration: (json['addPlanDuration'] as num?)?.toInt(),
);

Map<String, dynamic> _$QuotaModelToJson(QuotaModel instance) =>
    <String, dynamic>{
      'customerId': instance.customerId,
      'quatoType': instance.quatoType,
      'packageType': instance.packageType,
      'addCloudStorageQuotaByte': instance.addCloudStorageQuotaByte,
      'addTranscriptionMinutesQuota': instance.addTranscriptionMinutesQuota,
      'addPlanDuration': instance.addPlanDuration,
    };

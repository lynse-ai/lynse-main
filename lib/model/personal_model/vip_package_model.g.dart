// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vip_package_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VIPackageModel _$VIPackageModelFromJson(
  Map<String, dynamic> json,
) => VIPackageModel(
  productId: json['productId'] as String?,
  packageType: json['packageType'] as String?,
  price: (json['price'] as num?)?.toDouble(),
  paymentPeriod: json['paymentPeriod'] as String?,
  transcriptionQuota: (json['transcriptionQuota'] as num?)?.toInt(),
  visualizationSupport: (json['visualizationSupport'] as num?)?.toInt(),
  recordingSummarySupport: (json['recordingSummarySupport'] as num?)?.toInt(),
  recordingConclusionSupport:
      (json['recordingConclusionSupport'] as num?)?.toInt(),
  speakerDetectionSupport: (json['speakerDetectionSupport'] as num?)?.toInt(),
  audioImportSupport: (json['audioImportSupport'] as num?)?.toInt(),
  multiGuideSupport: (json['multiGuideSupport'] as num?)?.toInt(),
  ossStorageQuota: (json['ossStorageQuota'] as num?)?.toInt(),
  ossStorageQuotaByte: (json['ossStorageQuotaByte'] as num?)?.toInt(),
  planDuration: (json['planDuration'] as num?)?.toInt(),
);

Map<String, dynamic> _$VIPackageModelToJson(VIPackageModel instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'packageType': instance.packageType,
      'price': instance.price,
      'paymentPeriod': instance.paymentPeriod,
      'transcriptionQuota': instance.transcriptionQuota,
      'visualizationSupport': instance.visualizationSupport,
      'recordingSummarySupport': instance.recordingSummarySupport,
      'recordingConclusionSupport': instance.recordingConclusionSupport,
      'speakerDetectionSupport': instance.speakerDetectionSupport,
      'audioImportSupport': instance.audioImportSupport,
      'multiGuideSupport': instance.multiGuideSupport,
      'ossStorageQuota': instance.ossStorageQuota,
      'ossStorageQuotaByte': instance.ossStorageQuotaByte,
      'planDuration': instance.planDuration,
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_quato_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomerQuatoModel _$CustomerQuatoModelFromJson(Map<String, dynamic> json) =>
    CustomerQuatoModel(
      reservePackageType: json['reservePackageType'] as String?,
      reserveCloudStorageQuotaByte:
          (json['reserveCloudStorageQuotaByte'] as num?)?.toInt(),
      reserveTranscriptionMinutesQuota:
          (json['reserveTranscriptionMinutesQuota'] as num?)?.toInt(),
      paymentType: json['paymentType'] as String?,
      reservePackageEffectiveDuration:
          (json['reservePackageEffectiveDuration'] as num?)?.toInt(),
      reservePackageEffectiveStartTime:
          json['reservePackageEffectiveStartTime'] as String?,
      reservePackageInvalidTime: json['reservePackageInvalidTime'] as String?,
    );

Map<String, dynamic> _$CustomerQuatoModelToJson(
  CustomerQuatoModel instance,
) => <String, dynamic>{
  'reservePackageType': instance.reservePackageType,
  'reserveCloudStorageQuotaByte': instance.reserveCloudStorageQuotaByte,
  'reserveTranscriptionMinutesQuota': instance.reserveTranscriptionMinutesQuota,
  'paymentType': instance.paymentType,
  'reservePackageEffectiveDuration': instance.reservePackageEffectiveDuration,
  'reservePackageEffectiveStartTime': instance.reservePackageEffectiveStartTime,
  'reservePackageInvalidTime': instance.reservePackageInvalidTime,
};

import 'package:json_annotation/json_annotation.dart';

part 'customer_quato_model.g.dart';

@JsonSerializable()
class CustomerQuatoModel {
  String? reservePackageType;
  int? reserveCloudStorageQuotaByte;
  int? reserveTranscriptionMinutesQuota;
  String? paymentType;
  int? reservePackageEffectiveDuration;
  String? reservePackageEffectiveStartTime;
  String? reservePackageInvalidTime;

  CustomerQuatoModel({
    this.reservePackageType,
    this.reserveCloudStorageQuotaByte,
    this.reserveTranscriptionMinutesQuota,
    this.paymentType,
    this.reservePackageEffectiveDuration,
    this.reservePackageEffectiveStartTime,
    this.reservePackageInvalidTime,
  });

  factory CustomerQuatoModel.fromJson(Map<String, dynamic> json) =>
      _$CustomerQuatoModelFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerQuatoModelToJson(this);
}

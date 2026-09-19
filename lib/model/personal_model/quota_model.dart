import 'package:json_annotation/json_annotation.dart';

part 'quota_model.g.dart';

@JsonSerializable()
class QuotaModel {
  String? customerId;
  String? quatoType;
  String? packageType;
  int? addCloudStorageQuotaByte;
  int? addTranscriptionMinutesQuota;
  int? addPlanDuration;

  QuotaModel({
    this.customerId,
    this.quatoType,
    this.packageType,
    this.addCloudStorageQuotaByte,
    this.addTranscriptionMinutesQuota,
    this.addPlanDuration,
  });

  factory QuotaModel.fromJson(Map<String, dynamic> json) =>
      _$QuotaModelFromJson(json);
  Map<String, dynamic> toJson() => _$QuotaModelToJson(this);
}

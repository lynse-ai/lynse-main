import 'package:json_annotation/json_annotation.dart';

part 'vip_package_model.g.dart';

@JsonSerializable()
class VIPackageModel {
  String? productId; 
  String? packageType;
  double? price; 
  String ?paymentPeriod;
  int? transcriptionQuota;
  int? visualizationSupport;
  int? recordingSummarySupport;
  int? recordingConclusionSupport;
  int? speakerDetectionSupport;
  int? audioImportSupport;
  int? multiGuideSupport;
  int? ossStorageQuota;
  int? ossStorageQuotaByte;
  int? planDuration;

  VIPackageModel({
    this.productId, 
    this.packageType, 
    this.price,
    this.paymentPeriod,
    this.transcriptionQuota,
    this.visualizationSupport,
    this.recordingSummarySupport,
    this.recordingConclusionSupport,
    this.speakerDetectionSupport,
    this.audioImportSupport,
    this.multiGuideSupport,
    this.ossStorageQuota,
    this.ossStorageQuotaByte,
    this.planDuration,
  });

  @JsonKey(includeFromJson: false, includeToJson: false)
  double get transMinute =>
      transcriptionQuota != null
          ? double.parse((transcriptionQuota! / 60).toStringAsFixed(2))
          : 0;

  factory VIPackageModel.fromJson(Map<String, dynamic> json) =>
      _$VIPackageModelFromJson(json);
  Map<String, dynamic> toJson() => _$VIPackageModelToJson(this);
}

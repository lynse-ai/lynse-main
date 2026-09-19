import 'package:json_annotation/json_annotation.dart';

part 'point_history_log.g.dart';

@JsonSerializable()
class PointHisToryLogModel {
  String? id;
  String? tenantId;
  String? createBy;
  String? createTime;
  String? teamId;
  int? businessType;
  int? pointsAmount;
  String? operationType;
  String? operateTime;
  String? pointsLogType;
  int? changeType;
  String? pointsDetails;
  String? nickname;

  PointHisToryLogModel({
    this.id,
    this.tenantId,
    this.createBy,
    this.createTime,
    this.teamId,
    this.businessType,
    this.pointsAmount,
    this.operationType,
    this.operateTime,
    this.pointsLogType,
    this.changeType,
    this.pointsDetails,
    this.nickname,
  });
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get changeTypeString =>
      changeType == 0
          ? "pay0"
          : changeType == 1
          ? "pay1"
          : changeType == 2
          ? "pay2"
          : changeType == 3
          ? "pay3"
          : changeType == 4
          ? "pay4"
          : changeType == 5
          ? "pay5"
          : "pay6";

  factory PointHisToryLogModel.fromJson(Map<String, dynamic> json) =>
      _$PointHisToryLogModelFromJson(json);
  Map<String, dynamic> toJson() => _$PointHisToryLogModelToJson(this);
}

import 'package:json_annotation/json_annotation.dart';

part 'summary_model.g.dart';

@JsonSerializable()
class SummaryModel {
  String? id;
  String? tenantId;
  String? createBy;
  String? createTime;
  String? updateBy;
  String? updateTime;
  String? fileId;
  String? conclusionText;
  String? feedback;
  String? taskId;
  String? againTaskId;

  SummaryModel({
    this.id,
    this.tenantId,
    this.createBy,
    this.createTime,
    this.updateBy,
    this.updateTime,
    this.fileId,
    this.conclusionText,
    this.feedback,
    this.taskId,
    this.againTaskId,
  });

  factory SummaryModel.fromJson(Map<String, dynamic> json) =>
      _$SummaryModelFromJson(json);
  Map<String, dynamic> toJson() => _$SummaryModelToJson(this);
}

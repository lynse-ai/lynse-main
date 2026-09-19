import 'package:json_annotation/json_annotation.dart';

part 'outline_model.g.dart';

@JsonSerializable()
class OutLineModel {
  String? id;
  String? tenantId;
  String? createBy;
  String? createTime;
  String? updateBy;
  String? updateTime;
  String? fileId;
  String? outlineText;
  String? feedback;
  String? taskId;
  String? againTaskId;

  OutLineModel({
    this.id,
    this.tenantId,
    this.createBy,
    this.createTime,
    this.updateBy,
    this.updateTime,
    this.fileId,
    this.outlineText,
    this.feedback,
    this.taskId,
    this.againTaskId,
  });

  factory OutLineModel.fromJson(Map<String, dynamic> json) =>
      _$OutLineModelFromJson(json);
  Map<String, dynamic> toJson() => _$OutLineModelToJson(this);
}

import 'package:json_annotation/json_annotation.dart';

part 'minmap_model.g.dart';

@JsonSerializable()
class MindMapModel {
  String? id;
  String? tenantId;
  String? createBy;
  String? createTime;
  String? updateBy;
  String? updateTime;
  String? fileId;
  String? mindMapText;

  MindMapModel({
    this.id,
    this.tenantId,
    this.createBy,
    this.createTime,
    this.updateBy,
    this.updateTime,
    this.fileId,
    this.mindMapText,
  });

  factory MindMapModel.fromJson(Map<String, dynamic> json) =>
      _$MindMapModelFromJson(json);
  Map<String, dynamic> toJson() => _$MindMapModelToJson(this);
}

import 'package:json_annotation/json_annotation.dart';

part 'trans_model.g.dart';

@JsonSerializable()
class TransModel {
  String? id;
  String? tenantId;
  String? createBy;
  String? createTime;
  String? updateBy;
  String? updateTime;
  String? taskId;
  int? beginTime;
  int? silenceDuration;
  String? speakerId;
  String? speakerName;
  int? endTime;
  String? text;
  String? beginTimeStr;
  String? endTimeStr;
  TransModel({
    this.id,
    this.tenantId,
    this.createBy,
    this.createTime,
    this.updateBy,
    this.updateTime,
    this.taskId,
    this.beginTime,
    this.silenceDuration,
    this.speakerId,
    this.speakerName,
    this.endTime,
    this.text,
    this.beginTimeStr,
    this.endTimeStr,
  });

  factory TransModel.fromJson(Map<String, dynamic> json) =>
      _$TransModelFromJson(json);
  Map<String, dynamic> toJson() => _$TransModelToJson(this);
}

import 'package:json_annotation/json_annotation.dart';

part 'edit_trans_model.g.dart';

@JsonSerializable()
class EditTransModel {
  String? recordId;
  String? speakerId;
  String? speakerName;
  int? endTime;
  String? text;
  EditTransModel({
    this.recordId,
    this.speakerId,
    this.speakerName,
    this.endTime,
    this.text,
  });

  factory EditTransModel.fromJson(Map<String, dynamic> json) =>
      _$EditTransModelFromJson(json);
  Map<String, dynamic> toJson() => _$EditTransModelToJson(this);
}

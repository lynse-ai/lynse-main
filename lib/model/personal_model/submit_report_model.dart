import 'package:json_annotation/json_annotation.dart';

part 'submit_report_model.g.dart';

@JsonSerializable()
class SubmitReportModel {
  String? mediaUrl;
  String? sort;

  SubmitReportModel({this.mediaUrl, this.sort});

  factory SubmitReportModel.fromJson(Map<String, dynamic> json) =>
      _$SubmitReportModelFromJson(json);

  Map<String, dynamic> toJson() => _$SubmitReportModelToJson(this);
}

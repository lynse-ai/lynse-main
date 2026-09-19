import 'package:json_annotation/json_annotation.dart';

part 'response_share_team_model.g.dart';

@JsonSerializable()
class ResponseShareTeamModel {
  String fileId;
  String teamId;
  factory ResponseShareTeamModel.genDefault() {
    return ResponseShareTeamModel(fileId: "", teamId: "");
  }
  ResponseShareTeamModel({required this.fileId, required this.teamId});
  factory ResponseShareTeamModel.fromJson(Map<String, dynamic> json) =>
      _$ResponseShareTeamModelFromJson(json);
  Map<String, dynamic> toJson() => _$ResponseShareTeamModelToJson(this);
}

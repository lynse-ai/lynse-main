import 'package:json_annotation/json_annotation.dart';

part 'members_model.g.dart';

@JsonSerializable()
class MembersModel {
  String teamId;
  String? memberId;
  int role;
  String? avatarUrl; //权限设置
  String? nickname;
  String id;
  MembersModel({
    required this.role,
    required this.teamId,
    this.memberId,
    this.avatarUrl,
    this.nickname,
    required this.id,
  });
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get roleString =>
      role == 0
          ? "member"
          : role == 1
          ? "manager"
          : "owner";

  factory MembersModel.genDefault() {
    return MembersModel(role: 0, teamId: "", memberId: "", id: "");
  }

  factory MembersModel.fromJson(Map<String, dynamic> json) =>
      _$MembersModelFromJson(json);
  Map<String, dynamic> toJson() => _$MembersModelToJson(this);
}

import 'package:json_annotation/json_annotation.dart';

part 'inviter_team_model.g.dart';

@JsonSerializable()
class InviterTeamModel {
  String id;
  String? teamId;
  String? inviterId;
  String? inviterNickname;
  String? inviteeId;
  String? inviteePhone;
  int? inviteRole;
  int? status;
  String? inviteTime;
  String? acceptTime;
  String? teamName;
  String? avatarUrl;

  InviterTeamModel({
    required this.id,
    this.teamId,
    this.inviterId,
    this.inviterNickname,
    this.inviteeId,
    this.inviteePhone,
    this.inviteRole,
    this.status,
    this.inviteTime,
    this.acceptTime,
    this.teamName,
    this.avatarUrl,
  });

  factory InviterTeamModel.fromJson(Map<String, dynamic> json) =>
      _$InviterTeamModelFromJson(json);
  Map<String, dynamic> toJson() => _$InviterTeamModelToJson(this);
}

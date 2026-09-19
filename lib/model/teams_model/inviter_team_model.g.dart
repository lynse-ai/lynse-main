// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inviter_team_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InviterTeamModel _$InviterTeamModelFromJson(Map<String, dynamic> json) =>
    InviterTeamModel(
      id: json['id'] as String,
      teamId: json['teamId'] as String?,
      inviterId: json['inviterId'] as String?,
      inviterNickname: json['inviterNickname'] as String?,
      inviteeId: json['inviteeId'] as String?,
      inviteePhone: json['inviteePhone'] as String?,
      inviteRole: (json['inviteRole'] as num?)?.toInt(),
      status: (json['status'] as num?)?.toInt(),
      inviteTime: json['inviteTime'] as String?,
      acceptTime: json['acceptTime'] as String?,
      teamName: json['teamName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );

Map<String, dynamic> _$InviterTeamModelToJson(InviterTeamModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'teamId': instance.teamId,
      'inviterId': instance.inviterId,
      'inviterNickname': instance.inviterNickname,
      'inviteeId': instance.inviteeId,
      'inviteePhone': instance.inviteePhone,
      'inviteRole': instance.inviteRole,
      'status': instance.status,
      'inviteTime': instance.inviteTime,
      'acceptTime': instance.acceptTime,
      'teamName': instance.teamName,
      'avatarUrl': instance.avatarUrl,
    };

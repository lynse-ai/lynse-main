// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'members_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MembersModel _$MembersModelFromJson(Map<String, dynamic> json) => MembersModel(
  role: (json['role'] as num).toInt(),
  teamId: json['teamId'] as String,
  memberId: json['memberId'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  nickname: json['nickname'] as String?,
  id: json['id'] as String,
);

Map<String, dynamic> _$MembersModelToJson(MembersModel instance) =>
    <String, dynamic>{
      'teamId': instance.teamId,
      'memberId': instance.memberId,
      'role': instance.role,
      'avatarUrl': instance.avatarUrl,
      'nickname': instance.nickname,
      'id': instance.id,
    };

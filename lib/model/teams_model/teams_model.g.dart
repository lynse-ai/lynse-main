// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teams_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeamsModel _$TeamsModelFromJson(Map<String, dynamic> json) => TeamsModel(
  teamName: json['teamName'] as String,
  id: json['id'] as String,
  pointsAmount: (json['pointsAmount'] as num?)?.toInt(),
  owner: json['owner'] as String?,
  memberCapacity: (json['memberCapacity'] as num).toInt(),
  members:
      (json['members'] as List<dynamic>?)
          ?.map((e) => MembersModel.fromJson(e as Map<String, dynamic>))
          .toList(),
  avatarUrl: json['avatarUrl'] as String?,
  currentCustomerRole: (json['currentCustomerRole'] as num?)?.toInt(),
  allowDeletion: (json['allowDeletion'] as num?)?.toInt(),
  usedPointsAmount: (json['usedPointsAmount'] as num?)?.toInt(),
);

Map<String, dynamic> _$TeamsModelToJson(TeamsModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'teamName': instance.teamName,
      'owner': instance.owner,
      'avatarUrl': instance.avatarUrl,
      'pointsAmount': instance.pointsAmount,
      'usedPointsAmount': instance.usedPointsAmount,
      'memberCapacity': instance.memberCapacity,
      'members': instance.members,
      'currentCustomerRole': instance.currentCustomerRole,
      'allowDeletion': instance.allowDeletion,
    };

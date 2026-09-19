// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'userinfo_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserInfoModel _$UserInfoModelFromJson(Map<String, dynamic> json) =>
    UserInfoModel(
      id: json['id'] as String,
      username: json['username'] as String?,
      password: json['password'] as String?,
      nickname: json['nickname'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      sex: json['sex'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      wxOpenid: json['wxOpenid'] as String?,
      wxUnionid: json['wxUnionid'] as String?,
      registrationTime: json['registrationTime'] as String?,
      ipaddr: json['ipaddr'] as String?,
      packageType: json['packageType'] as String?,
      ossStorageUsage: (json['ossStorageUsage'] as num?)?.toInt(),
      benefitType: json['benefitType'] as String?,
      pointsAmount: (json['pointsAmount'] as num?)?.toInt(),
      usedPointsAmount: (json['usedPointsAmount'] as num?)?.toInt(),
      initialRewardClaimed: (json['initialRewardClaimed'] as num?)?.toInt(),
      teamId: json['teamId'] as String?,
      upgradeBenefitStartTime: json['upgradeBenefitStartTime'] as String?,
      upgradeBenefitEndTime: json['upgradeBenefitEndTime'] as String?,
      macAddressList:
          (json['macAddressList'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
    )..realName = json['realName'] as String?;

Map<String, dynamic> _$UserInfoModelToJson(UserInfoModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'password': instance.password,
      'nickname': instance.nickname,
      'email': instance.email,
      'phone': instance.phone,
      'sex': instance.sex,
      'avatarUrl': instance.avatarUrl,
      'wxOpenid': instance.wxOpenid,
      'wxUnionid': instance.wxUnionid,
      'realName': instance.realName,
      'registrationTime': instance.registrationTime,
      'ipaddr': instance.ipaddr,
      'packageType': instance.packageType,
      'ossStorageUsage': instance.ossStorageUsage,
      'pointsAmount': instance.pointsAmount,
      'usedPointsAmount': instance.usedPointsAmount,
      'benefitType': instance.benefitType,
      'initialRewardClaimed': instance.initialRewardClaimed,
      'teamId': instance.teamId,
      'upgradeBenefitStartTime': instance.upgradeBenefitStartTime,
      'upgradeBenefitEndTime': instance.upgradeBenefitEndTime,
      'macAddressList': instance.macAddressList,
    };

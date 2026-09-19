import 'package:json_annotation/json_annotation.dart';

part 'userinfo_model.g.dart';

@JsonSerializable()
class UserInfoModel {
  String id;

  String? username;
  String? password;
  String? nickname;
  String? email;
  String? phone;
  String? sex;
  String? avatarUrl;
  String? wxOpenid;
  String? wxUnionid;
  String? realName;
  String? registrationTime;
  String? ipaddr;
  String? packageType;
  int? ossStorageUsage;

  int? pointsAmount; //持有积分总数
  int? usedPointsAmount; //已使用积分总数
  String? benefitType;
  int? initialRewardClaimed;
  String? teamId;
  String? upgradeBenefitStartTime;
  String? upgradeBenefitEndTime;
  List<String>? macAddressList;

  @JsonKey(includeFromJson: false, includeToJson: false)
  //积分总数
  int get pointsAmountInt =>
      pointsAmount != null ? int.parse(pointsAmount.toString()) : 0;
  //积分使用
  int get usedPointsAmountInt =>
      usedPointsAmount != null ? int.parse(usedPointsAmount.toString()) : 0;
  //积分剩余
  int get remainPointsAmountInt =>
      pointsAmountInt - usedPointsAmountInt < 0
          ? 0
          : pointsAmountInt - usedPointsAmountInt;
  //使用积分与总数的百分比
  double get percentPointsAmountDouble =>
      pointsAmountInt != 0 ? usedPointsAmountInt / pointsAmountInt : 0.0;

  UserInfoModel({
    required this.id,
    this.username,
    this.password,
    this.nickname,
    this.email,
    this.phone,
    this.sex,
    this.avatarUrl,
    this.wxOpenid,
    this.wxUnionid,
    this.registrationTime,
    this.ipaddr,
    this.packageType,
    this.ossStorageUsage,
    this.benefitType,
    this.pointsAmount,
    this.usedPointsAmount,
    this.initialRewardClaimed,
    this.teamId,
    this.upgradeBenefitStartTime,
    this.upgradeBenefitEndTime,
    this.macAddressList,
  });

  factory UserInfoModel.fromJson(Map<String, dynamic> json) =>
      _$UserInfoModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserInfoModelToJson(this);
}

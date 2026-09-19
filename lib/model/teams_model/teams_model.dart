import 'package:dting/model/teams_model/members_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'teams_model.g.dart';

@JsonSerializable()
class TeamsModel {
  String id;
  String teamName;
  String? owner; //所属人
  String? avatarUrl;
  int? pointsAmount;
  int? usedPointsAmount;
  int memberCapacity;
  List<MembersModel>? members;
  int? currentCustomerRole; //成员角色：0=普通成员，1=管理员， 2拥有者 ，只有拥有者才可以删除成员
  int? allowDeletion;

  @JsonKey(includeFromJson: false, includeToJson: false)
  //团队积分总数
  int get pointsAmountInt =>
      pointsAmount != null ? int.parse(pointsAmount.toString()) : 0;
  //团队积分使用数
  int get usedPointsAmountInt =>
      usedPointsAmount != null ? int.parse(usedPointsAmount.toString()) : 0;
  //团队成员个数
  int get membersInt => members != null ? members!.length : 0;

  //团队积分剩余
  int get remainPointsAmountInt =>
      pointsAmountInt - usedPointsAmountInt < 0
          ? 0
          : pointsAmountInt - usedPointsAmountInt;
  //使用积分与总数的百分比
  double get percentPointsAmountDouble =>
      pointsAmountInt != 0 ? usedPointsAmountInt / pointsAmountInt : 0.0;

  //席位总数与使用的席位百分比
  double get percentMembersDouble =>  membersInt != 0 ? membersInt / memberCapacity : 0.0;

  TeamsModel({
    required this.teamName,
    required this.id,
    this.pointsAmount,
    this.owner,
    required this.memberCapacity,
    this.members,
    this.avatarUrl,
    this.currentCustomerRole,
    this.allowDeletion,
    this.usedPointsAmount,
  });
  factory TeamsModel.genDefault() {
    return TeamsModel(
      id: "-1",
      teamName: "--",
      currentCustomerRole: 0,
      pointsAmount: 0,
      usedPointsAmount: 0,
      memberCapacity: 1,
      avatarUrl: null,
      owner: null,
      members: null,
    );
  }
  factory TeamsModel.fromJson(Map<String, dynamic> json) =>
      _$TeamsModelFromJson(json);
  Map<String, dynamic> toJson() => _$TeamsModelToJson(this);
}

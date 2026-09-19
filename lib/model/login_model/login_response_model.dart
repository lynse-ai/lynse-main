import 'package:json_annotation/json_annotation.dart';

part 'login_response_model.g.dart';

@JsonSerializable()
class LoginResponsetModel {
  String? token;
  int? expireIn;
  bool? firstLogin;
  bool? needBind;
  String? openId;
  String? customerId;
  String? thirdPartyId;
  LoginResponsetModel({
    this.token,
    this.openId,
    this.firstLogin,
    this.customerId,
    this.thirdPartyId,
    this.needBind,
    this.expireIn,
  });

  factory LoginResponsetModel.fromJson(Map<String, dynamic> json) =>
      _$LoginResponsetModelFromJson(json);
  Map<String, dynamic> toJson() => _$LoginResponsetModelToJson(this);
}

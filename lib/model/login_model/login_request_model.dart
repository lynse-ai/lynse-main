import 'package:json_annotation/json_annotation.dart';

part 'login_request_model.g.dart';

@JsonSerializable()
class LoginRequestModel {
  String authType;
  String? username;
  String? password;
  String? code;
  String? state;
  String? deviceType;
  bool? captchaEnable;
  String? identityToken;
  String? captchaCode;

  LoginRequestModel({
    required this.authType,
    this.username,
    this.password,
    this.code,
    this.state,
    this.deviceType,
    this.captchaEnable,
    this.identityToken,
    this.captchaCode,
  });

  factory LoginRequestModel.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestModelFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestModelToJson(this);
}

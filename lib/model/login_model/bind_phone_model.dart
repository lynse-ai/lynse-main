import 'package:json_annotation/json_annotation.dart';

part 'bind_phone_model.g.dart';

@JsonSerializable()
class BindPhoneModel {
  String authType;
  String username;
  String thirdPartyId;
  String captchaCode;

  BindPhoneModel({
    required this.authType,
    required this.username,
    required this.thirdPartyId,
    required this.captchaCode,
  });

  factory BindPhoneModel.fromJson(Map<String, dynamic> json) =>
      _$BindPhoneModelFromJson(json);
  Map<String, dynamic> toJson() => _$BindPhoneModelToJson(this);
}

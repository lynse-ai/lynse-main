import 'package:json_annotation/json_annotation.dart';

part 'verificationcode_email_model.g.dart';

@JsonSerializable()
class VerificationCodeByEmailModel {
  String email;
  String actionType;

  VerificationCodeByEmailModel({required this.email, required this.actionType});

  factory VerificationCodeByEmailModel.fromJson(Map<String, dynamic> json) =>
      _$VerificationCodeByEmailModelFromJson(json);
  Map<String, dynamic> toJson() => _$VerificationCodeByEmailModelToJson(this);
}

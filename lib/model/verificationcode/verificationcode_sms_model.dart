import 'package:json_annotation/json_annotation.dart';

part 'verificationcode_sms_model.g.dart';

@JsonSerializable()
class VerificationCodeBySMSModel {
  String phone;
  String actionType;

  VerificationCodeBySMSModel({required this.phone, required this.actionType});

  factory VerificationCodeBySMSModel.fromJson(Map<String, dynamic> json) =>
      _$VerificationCodeBySMSModelFromJson(json);
  Map<String, dynamic> toJson() => _$VerificationCodeBySMSModelToJson(this);
}

import 'package:json_annotation/json_annotation.dart';

part 'pay_model.g.dart';

@JsonSerializable()
class PayRequestModel {
  String orderNo;
  String payPlatform;
  String? platPayWay;
  String? openId;

  PayRequestModel({
    required this.orderNo,
    required this.payPlatform,
    this.platPayWay,
    this.openId,
  });

  factory PayRequestModel.fromJson(Map<String, dynamic> json) =>
      _$PayRequestModelFromJson(json);
  Map<String, dynamic> toJson() => _$PayRequestModelToJson(this);
}

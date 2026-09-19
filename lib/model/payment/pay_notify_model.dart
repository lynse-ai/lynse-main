import 'package:json_annotation/json_annotation.dart';

part 'pay_notify_model.g.dart';

@JsonSerializable()
class PayNotifyModel {
  String? tenantId;
  String? orderNo;
  String? subOrderNo;
  String? payPlatform;
  String? platPayWay;
  String? providerId;
  String? merchantId;
  String? status;
  String receipt;
  String? chooseEnv;
  String? customerId;

  PayNotifyModel({
    this.tenantId,
    this.orderNo,
    this.subOrderNo,
    this.payPlatform,
    this.platPayWay,
    this.providerId,
    this.merchantId,
    this.status,
    required this.receipt,
    this.chooseEnv,
    this.customerId,
  });

  factory PayNotifyModel.fromJson(Map<String, dynamic> json) =>
      _$PayNotifyModelFromJson(json);
  Map<String, dynamic> toJson() => _$PayNotifyModelToJson(this);
}

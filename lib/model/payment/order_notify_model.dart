import 'package:json_annotation/json_annotation.dart';

part 'order_notify_model.g.dart';

@JsonSerializable()
class OrderNotifyModel {
  String? tenantId;
  String? orderNo;
  String? payPlatform;
  String? platPayWay;
  String? providerId;
  String? merchantId;
  String? status;

  OrderNotifyModel({
    this.tenantId,
    this.orderNo,
    this.payPlatform,
    this.platPayWay,
    this.providerId,
    this.merchantId,
    this.status,
  });

  factory OrderNotifyModel.fromJson(Map<String, dynamic> json) =>
      _$OrderNotifyModelFromJson(json);
  Map<String, dynamic> toJson() => _$OrderNotifyModelToJson(this);
}

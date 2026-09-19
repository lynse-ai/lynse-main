import 'package:json_annotation/json_annotation.dart';

part 'order_pay_model.g.dart';

@JsonSerializable()
class OrderPayResponseModel {
  String? timestamp;
  String? prepayid;
  String? sign;
  String? noncestr;
  String? appid;
  String? partnerid;

  OrderPayResponseModel({
    this.timestamp,
    this.prepayid,
    this.sign,
    this.noncestr,
    this.appid,
    this.partnerid,
  });

  factory OrderPayResponseModel.fromJson(Map<String, dynamic> json) =>
      _$OrderPayResponseModelFromJson(json);
  Map<String, dynamic> toJson() => _$OrderPayResponseModelToJson(this);
}

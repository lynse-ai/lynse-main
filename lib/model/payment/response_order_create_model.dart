import 'package:json_annotation/json_annotation.dart';

part 'response_order_create_model.g.dart';

@JsonSerializable()
class ResponseOrderCreateModel {
  String orderNo;
  double? fee;

  ResponseOrderCreateModel({required this.orderNo, this.fee});

  factory ResponseOrderCreateModel.fromJson(Map<String, dynamic> json) =>
      _$ResponseOrderCreateModelFromJson(json);
  Map<String, dynamic> toJson() => _$ResponseOrderCreateModelToJson(this);
}

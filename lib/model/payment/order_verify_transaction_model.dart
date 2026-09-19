import 'package:json_annotation/json_annotation.dart';
part 'order_verify_transaction_model.g.dart';

@JsonSerializable()
class OrderVerifyTransactionModel {
  String? receipt;
  bool? chooseEnv;
  String transactionId;
  String orderNo;

  OrderVerifyTransactionModel({
    this.chooseEnv,
    required this.transactionId,
    this.receipt,
    required this.orderNo,
  });

  factory OrderVerifyTransactionModel.fromJson(Map<String, dynamic> json) =>
      _$OrderVerifyTransactionModelFromJson(json);
  Map<String, dynamic> toJson() => _$OrderVerifyTransactionModelToJson(this);
}

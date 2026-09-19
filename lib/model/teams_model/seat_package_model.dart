import 'package:json_annotation/json_annotation.dart';

part 'seat_package_model.g.dart';

@JsonSerializable()
class SeatPackageModel {
  String id;
  String teamSeatPackageCode;
  int? teamSeatAmount;
  double? originalPrice;
  double? discountRate;
  double? discountPrice;
  int? status;
  int? sortOrder;

  SeatPackageModel({
    required this.id,
    required this.teamSeatPackageCode,
    this.teamSeatAmount,
    this.discountRate,
    this.discountPrice,
    this.originalPrice,
    this.status,
    this.sortOrder,
  });

  factory SeatPackageModel.fromJson(Map<String, dynamic> json) =>
      _$SeatPackageModelFromJson(json);
  Map<String, dynamic> toJson() => _$SeatPackageModelToJson(this);
}

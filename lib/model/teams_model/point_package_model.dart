import 'package:json_annotation/json_annotation.dart';

part 'point_package_model.g.dart';

@JsonSerializable()
class PointPackageModel {
  String id;
  String pointsPackageCode;
  String? pointsPackageName;
  int? pointsAmount;
  double? discountRate;
  double originalPrice;
  double? discountPrice;
  String? pointsPackageType;
  String? channel;
  int? status;
  int? sort;

  PointPackageModel({
    required this.id,
    required this.pointsPackageCode,
    this.pointsPackageName,
    this.pointsAmount,
    this.discountRate,
    required this.originalPrice,
    this.discountPrice,
    this.pointsPackageType,
    this.channel,
    this.status,
    this.sort,
  });

  factory PointPackageModel.genDefault() {
    return PointPackageModel(id: '', pointsPackageCode: '', originalPrice: 0);
  }

  factory PointPackageModel.fromJson(Map<String, dynamic> json) =>
      _$PointPackageModelFromJson(json);
  Map<String, dynamic> toJson() => _$PointPackageModelToJson(this);
}

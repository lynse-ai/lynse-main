import 'package:json_annotation/json_annotation.dart';

part 'search_device_model.g.dart';

@JsonSerializable()
class SearchBindDeviceModel {
  String macAddress;
  int bindStatus;
  int isBoundByMe;
  String? phone;

  SearchBindDeviceModel({
    required this.macAddress,
    required this.bindStatus,
    required this.isBoundByMe,
    this.phone,
  });

  factory SearchBindDeviceModel.fromJson(Map<String, dynamic> json) =>
      _$SearchBindDeviceModelFromJson(json);
  Map<String, dynamic> toJson() => _$SearchBindDeviceModelToJson(this);
}

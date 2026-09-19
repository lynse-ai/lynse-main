import 'package:json_annotation/json_annotation.dart';

part 'editdeviceinfo_model.g.dart';

@JsonSerializable()
class EditDeviceInfoModel {
  String deviceId;
  String? name;
  String? serialNumber;
  String? storageCapacity;
  String? usedSpace;
  String? version;

  EditDeviceInfoModel({
    required this.deviceId,
    this.name,
    this.serialNumber,
    this.storageCapacity,
    this.usedSpace,
    this.version,
  });

  factory EditDeviceInfoModel.fromJson(Map<String, dynamic> json) =>
      _$EditDeviceInfoModelFromJson(json);
  Map<String, dynamic> toJson() => _$EditDeviceInfoModelToJson(this);
}

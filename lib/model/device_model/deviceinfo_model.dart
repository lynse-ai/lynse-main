import 'package:json_annotation/json_annotation.dart';

part 'deviceinfo_model.g.dart';

@JsonSerializable()
class DeviceInfoModel {
  String? id;
  String? tenantId;
  String? createBy;
  String? createTime;
  String? updateBy;
  String? updateTime;
  String? deviceName;
  String? serialNumber;
  String? macAddress;
  String? storageCapacity;
  String? usedSpace;
  String? version;
  int? bindStatus;
  String? owner;
  String? caseBattery;
  String? nickname;

  DeviceInfoModel({
    this.id,
    this.tenantId,
    this.createBy,
    this.createTime,
    this.updateBy,
    this.updateTime,
    this.deviceName,
    this.serialNumber,
    this.macAddress,
    this.storageCapacity,
    this.usedSpace,
    this.version,
    this.bindStatus,
    this.owner,
    this.caseBattery,
  });

  factory DeviceInfoModel.genDefault() {
    return DeviceInfoModel(id: "");
  }

  factory DeviceInfoModel.fromJson(Map<String, dynamic> json) =>
      _$DeviceInfoModelFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceInfoModelToJson(this);
}

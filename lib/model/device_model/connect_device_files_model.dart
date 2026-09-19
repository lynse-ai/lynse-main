import 'package:json_annotation/json_annotation.dart';

part 'connect_device_files_model.g.dart';

@JsonSerializable()
class ConnectDeviceFilesModel {
  String sn;
  String size;
  String endTimestamp;
  String startTimestamp;
  String name;
  String scene;

  ConnectDeviceFilesModel({
    required this.sn,
    required this.size,
    required this.endTimestamp,
    required this.startTimestamp,
    required this.name,
    required this.scene,
  });

  factory ConnectDeviceFilesModel.fromJson(Map<String, dynamic> json) =>
      _$ConnectDeviceFilesModelFromJson(json);
  Map<String, dynamic> toJson() => _$ConnectDeviceFilesModelToJson(this);
}

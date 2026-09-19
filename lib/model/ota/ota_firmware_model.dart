import 'package:json_annotation/json_annotation.dart';

part 'ota_firmware_model.g.dart';

@JsonSerializable()
class OtaFirmwareModel {
  final String version;
  final String url;
  final String path;
  final String name;

  const OtaFirmwareModel(this.version, this.url, this.path, this.name);

  factory OtaFirmwareModel.fromJson(Map<String, dynamic> json) =>
      _$OtaFirmwareModelFromJson(json);
  Map<String, dynamic> toJson() => _$OtaFirmwareModelToJson(this);
}

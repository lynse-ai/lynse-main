import 'package:json_annotation/json_annotation.dart';

part 'ota_version_model.g.dart';

@JsonSerializable()
class OtaVersionModel {
  String id;
  OtaVersionPlatform platform;
  String versionName;
  String updateLog;
  String ossUrl;
  int forceUpdate;
  String filename;
  String? path;
  String? contentType;
  OtaVersionModel(
    this.id,
    this.platform,
    this.versionName,
    this.updateLog,
    this.ossUrl,
    this.forceUpdate,
    this.filename,
    this.path,
    this.contentType,
  );

  factory OtaVersionModel.fromJson(Map<String, dynamic> json) =>
      _$OtaVersionModelFromJson(json);

  Map<String, dynamic> toJson() => _$OtaVersionModelToJson(this);
}

enum OtaVersionPlatform { android, ios }

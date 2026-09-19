import 'package:json_annotation/json_annotation.dart';

part 'upload_file_model.g.dart';

@JsonSerializable()
class UploadFileModel {
  String? customerId;
  String? saveFilename;
  String? path;
  String? objectId;
  String? objectType;
  String? folderId;
  String? macAddress;
  String? location;
  int? bizDuration;
  String? mode;
  int? fileSize;
  String? teamId;
  String? recordStartTime;
  int? scene;

  UploadFileModel({
    this.customerId,
    this.path,
    this.saveFilename,
    this.objectId,
    this.objectType,
    this.folderId,
    this.macAddress,
    this.location,
    this.bizDuration,
    this.mode,
    this.fileSize,
    this.teamId,
    this.recordStartTime,
    this.scene,
  });

  factory UploadFileModel.fromJson(Map<String, dynamic> json) =>
      _$UploadFileModelFromJson(json);
  Map<String, dynamic> toJson() => _$UploadFileModelToJson(this);
}

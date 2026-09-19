import 'package:dting/utils/local_database.dart';
import 'package:json_annotation/json_annotation.dart';

part 'file_info.g.dart';

@JsonSerializable()
class FileInfoModel {
  String? id;
  String? tenantId;
  String? createBy;
  String? createTime;
  String? updateBy;
  String? updateTime;
  String? url;
  String? filename;
  String? originalFilename;
  String? path;
  String? objectId;
  String? objectType;
  String? uploadId;
  int? uploadStatus;
  String? customerId;
  String? nickname;
  String? folderId;
  String? outlineId;
  String? conclusionId;
  String? mindMapId;
  String? transcribeTaskId;
  String? transcribeStatus;
  String? macAddress;
  String? location;
  int? bizDuration;
  int? isRead;
  String? mode;
  String? folderName;
  String? shareTime;
  String? avatarUrl;
  int? requiredPoints; //转译所需的积分
  int? isExamples; //转译所需的积分
  String? recordStartTime;

  FileInfoModel({
    this.id,
    this.tenantId,
    this.createBy,
    this.createTime,
    this.updateBy,
    this.updateTime,
    this.url,
    this.filename,
    this.originalFilename,
    this.path,
    this.objectId,
    this.objectType,
    this.uploadId,
    this.uploadStatus,
    this.customerId,
    this.nickname,
    this.folderId,
    this.outlineId,
    this.mindMapId,
    this.conclusionId,
    this.transcribeTaskId,
    this.transcribeStatus,
    this.macAddress,
    this.location,
    this.bizDuration,
    this.isRead,
    this.mode,
    this.folderName,
    this.shareTime,
    this.avatarUrl,
    this.requiredPoints,
    this.isExamples,
    this.recordStartTime,
  });
  String? language = LocalDataBase().basicBox!.get("language");

  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get modeString =>
      mode != null
          ? language == "en_US"
              ? mode
              : mode!.toUpperCase() == "MEETING"
              ? "会议录音"
              : mode!.toUpperCase() == "CALL"
              ? "通话录音"
              : "导入音频"
          : language == "en_US"
          ? "IMPORT"
          : "导入音频";

  factory FileInfoModel.fromJson(Map<String, dynamic> json) =>
      _$FileInfoModelFromJson(json);
  Map<String, dynamic> toJson() => _$FileInfoModelToJson(this);
}

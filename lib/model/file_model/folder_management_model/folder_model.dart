import 'package:json_annotation/json_annotation.dart';

part 'folder_model.g.dart';

@JsonSerializable()
class FolderInfo {
  String id;
  String? tenantId;
  String? createBy;
  String? createTime;
  String? updateBy;
  String? updateTime;
  String? folderName;
  String? color;

  FolderInfo({
    required this.id,
    this.tenantId,
    this.createBy,
    this.createTime,
    this.updateBy,
    this.updateTime,
    this.folderName,
    this.color,
  });

  factory FolderInfo.fromJson(Map<String, dynamic> json) =>
      _$FolderInfoFromJson(json);
  Map<String, dynamic> toJson() => _$FolderInfoToJson(this);
}

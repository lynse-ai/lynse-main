import 'package:json_annotation/json_annotation.dart';

part 'count_file_model.g.dart';

@JsonSerializable()
class FileCountModel {
  String ? folderId;
  int count; 
  FileCountModel({
    required this.folderId,
    required this.count, 
  });

  factory FileCountModel.fromJson(Map<String, dynamic> json) =>
      _$FileCountModelFromJson(json);
  Map<String, dynamic> toJson() => _$FileCountModelToJson(this);
}


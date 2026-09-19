import 'package:json_annotation/json_annotation.dart';

part 'change_folder_index_model.g.dart';

@JsonSerializable()
class ChangeFodlerIndexModel {
  int sort;
  String folderId;

  ChangeFodlerIndexModel({required this.sort, required this.folderId});

  factory ChangeFodlerIndexModel.fromJson(Map<String, dynamic> json) =>
      _$ChangeFodlerIndexModelFromJson(json);
  Map<String, dynamic> toJson() => _$ChangeFodlerIndexModelToJson(this);
}

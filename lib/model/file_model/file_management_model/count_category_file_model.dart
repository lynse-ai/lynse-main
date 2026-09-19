import 'package:dting/model/file_model/file_management_model/count_file_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'count_category_file_model.g.dart';

@JsonSerializable()
class FileCountByCategoryModel {
  int all;
  int unclassified;
  List<FileCountModel>? folderStats;
  int classified;

  FileCountByCategoryModel({
    required this.all,
    required this.unclassified,
    required this.folderStats,
    required this.classified,
  });
  factory FileCountByCategoryModel.genDefault() {
    return FileCountByCategoryModel(
      all: 0,
      unclassified: 0,
      folderStats: [],
      classified: 0,
    );
  }
  factory FileCountByCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$FileCountByCategoryModelFromJson(json);
  Map<String, dynamic> toJson() => _$FileCountByCategoryModelToJson(this);
}

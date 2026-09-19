import 'package:json_annotation/json_annotation.dart';

part 'page_size_model.g.dart';

@JsonSerializable()
class PageSizeModel {
  int page;
  int size;

  PageSizeModel({required this.page, required this.size});

  factory PageSizeModel.fromJson(Map<String, dynamic> json) =>
      _$PageSizeModelFromJson(json);
  Map<String, dynamic> toJson() => _$PageSizeModelToJson(this);
}

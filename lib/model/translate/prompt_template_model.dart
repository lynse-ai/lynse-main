import 'package:json_annotation/json_annotation.dart';

part 'prompt_template_model.g.dart';

@JsonSerializable()
class PromptTemplateModel {
  String? id;
  String? name;
  String? alias;
  String? category;
  int? sortOrder;
  String? content;
  String? userId;
  List<String>? tags;

  PromptTemplateModel({
    this.id,
    this.name,
    this.alias,
    this.category,
    this.sortOrder,
    this.content,
    this.userId,
    this.tags,
  });

  factory PromptTemplateModel.fromJson(Map<String, dynamic> json) {
    // 处理tags字段的类型转换
    if (json.containsKey('tags')) {
      final tagsValue = json['tags'];
      if (tagsValue is String) {
        // 如果tags是String类型，按逗号分割成List<String>
        json = Map<String, dynamic>.from(json);
        json['tags'] = tagsValue.split(',').map((tag) => tag.trim()).toList();
      } else if (tagsValue == null || tagsValue is! List) {
        // 如果tags不是List类型或为null，设置为空List
        json = Map<String, dynamic>.from(json);
        json['tags'] = [];
      }
    }

    return _$PromptTemplateModelFromJson(json);
  }

  Map<String, dynamic> toJson() => _$PromptTemplateModelToJson(this);
}

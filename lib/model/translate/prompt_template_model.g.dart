// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prompt_template_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PromptTemplateModel _$PromptTemplateModelFromJson(Map<String, dynamic> json) =>
    PromptTemplateModel(
      id: json['id'] as String?,
      name: json['name'] as String?,
      alias: json['alias'] as String?,
      category: json['category'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt(),
      content: json['content'] as String?,
      userId: json['userId'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$PromptTemplateModelToJson(
  PromptTemplateModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'alias': instance.alias,
  'category': instance.category,
  'sortOrder': instance.sortOrder,
  'content': instance.content,
  'userId': instance.userId,
  'tags': instance.tags,
};

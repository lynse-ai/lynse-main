// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mindmap_node_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NodeModel _$NodeModelFromJson(Map<String, dynamic> json) => NodeModel(
  id: json['id'] as String,
  topic: json['topic'] as String,
  root: json['root'] as bool,
  children:
      (json['children'] as List<dynamic>?)
          ?.map((e) => NodeModel.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$NodeModelToJson(NodeModel instance) => <String, dynamic>{
  'id': instance.id,
  'topic': instance.topic,
  'root': instance.root,
  'children': instance.children,
};

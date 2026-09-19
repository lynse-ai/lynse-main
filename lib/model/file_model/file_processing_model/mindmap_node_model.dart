import 'package:json_annotation/json_annotation.dart';

part 'mindmap_node_model.g.dart';

@JsonSerializable()
class NodeModel {
  String id;
  String topic;
  bool root;
  List<NodeModel>? children;

  NodeModel({
    required this.id,
    required this.topic,
    required this.root,
    this.children,
  });

  factory NodeModel.fromJson(Map<String, dynamic> json) =>
      _$NodeModelFromJson(json);
  Map<String, dynamic> toJson() => _$NodeModelToJson(this);
}

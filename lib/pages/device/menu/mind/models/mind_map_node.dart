class MindMapNode {
  final String id;
  final String text;
  final int level;
  final List<MindMapNode> children;
  final Map<String, dynamic> data;

  MindMapNode({
    required this.id,
    required this.text,
    required this.level,
    this.children = const [],
    this.data = const {},
  });

  MindMapNode copyWith({
    String? id,
    String? text,
    int? level,
    List<MindMapNode>? children,
    Map<String, dynamic>? data,
  }) {
    return MindMapNode(
      id: id ?? this.id,
      text: text ?? this.text,
      level: level ?? this.level,
      children: children ?? this.children,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'level': level,
      'children': children.map((child) => child.toJson()).toList(),
      'data': data,
    };
  }

  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    return MindMapNode(
      id: json['id'] as String,
      text: json['text'] as String,
      level: json['level'] as int,
      children: (json['children'] as List<dynamic>)
          .map((child) => MindMapNode.fromJson(child as Map<String, dynamic>))
          .toList(),
      data: Map<String, dynamic>.from(json['data'] as Map),
    );
  }
} 
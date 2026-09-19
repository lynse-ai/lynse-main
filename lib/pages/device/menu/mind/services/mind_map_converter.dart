import '../models/mind_map_node.dart';
import 'package:reactive_mind_map/reactive_mind_map.dart';

class MindMapConverter {
  static MindMapData convertToReactiveMindMap(MindMapNode rootNode) {
    return MindMapData(
      id: rootNode.id,
      title: rootNode.text,
      description: rootNode.children.isNotEmpty ? '${rootNode.children.length} 个子节点' : '',
      children: rootNode.children.map((child) => _convertNode(child)).toList(),
      customData: {'level': rootNode.level},
    );
  }
  
  static MindMapData _convertNode(MindMapNode node) {
    return MindMapData(
      id: node.id,
      title: node.text,
      description: node.children.isNotEmpty ? '${node.children.length} 个子节点' : '',
      children: node.children.map((child) => _convertNode(child)).toList(),
      customData: {'level': node.level},
    );
  }
  
  static List<Map<String, dynamic>> convertToFlatList(MindMapNode rootNode) {
    final List<Map<String, dynamic>> result = [];
    _addNodeToList(rootNode, result);
    return result;
  }
  
  static void _addNodeToList(MindMapNode node, List<Map<String, dynamic>> list) {
    list.add({
      'id': node.id,
      'text': node.text,
      'level': node.level,
      'data': node.data,
    });
    
    for (final child in node.children) {
      _addNodeToList(child, list);
    }
  }
} 
import '../models/mind_map_node.dart';

class MarkdownParser {
  static MindMapNode parseMarkdownToMindMap(String markdownText) {
    final lines = markdownText.split('\n');
    print('=== 开始解析Markdown ===');
    print('总行数: ${lines.length}');

    // 统计一级标题数量
    int h1Count = 0;
    int? h1Index;
    String? h1Text;
    for (int i = 0; i < lines.length; i++) {
      final match = RegExp(r'^# (.+)$').firstMatch(lines[i].trim());
      if (match != null) {
        h1Count++;
        if (h1Count == 1) {
          h1Text = match.group(1);
          h1Index = i;
        }
      }
    }

    MindMapNode rootNode;
    int startLine = 0;
    if (h1Count == 1 && h1Text != null && h1Index != null) {
      // 只有一个一级标题，直接用它作为根节点
      rootNode = MindMapNode(id: 'root', text: h1Text, level: 1);
      startLine = h1Index + 1; // 跳过第一个一级标题行
      print('唯一一级标题，根节点: $h1Text');
    } else {
      // 多个一级标题，使用虚拟根节点
      rootNode = MindMapNode(id: 'root', text: '思维导图', level: 0);
      print('使用虚拟根节点');
    }

    // 使用栈来维护当前层级关系，初始只有根节点
    final nodeStack = <MindMapNode>[rootNode];
    print('初始化栈，根节点: ${rootNode.text} (level: ${rootNode.level})');

    for (int i = startLine; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      // 检测标题级别
      final headingMatch = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final text = headingMatch.group(2)!.trim();
        print('发现标题: $text (level: $level)');
        final node = MindMapNode(
          id: 'node_${i}_$level',
          text: cleanMarkdownText(text),
          level: level,
        );
        print('当前栈深度: ${nodeStack.length}');
        print('栈顶节点: ${nodeStack.last.text} (level: ${nodeStack.last.level})');
        // 找到合适的父节点 - 移除所有层级大于等于当前标题的节点
        while (nodeStack.isNotEmpty && nodeStack.last.level >= level) {
          final removed = nodeStack.removeLast();
          print('移除栈顶节点: ${removed.text} (level: ${removed.level})');
        }
        // 将节点添加到当前栈顶的父节点
        if (nodeStack.isNotEmpty) {
          var parent = nodeStack.last;
          print('找到父节点: ${parent.text} (level: ${parent.level})');
          var updatedParent = parent.copyWith(
            children: [...parent.children, node],
          );
          print('更新父节点 ${parent.text}，子节点数量: ${updatedParent.children.length}');
          nodeStack[nodeStack.length - 1] = updatedParent;
          // 递归向上更新祖先链
          for (int j = nodeStack.length - 2; j >= 0; j--) {
            final ancestor = nodeStack[j];
            final updatedAncestor = ancestor.copyWith(
              children: [
                ...ancestor.children.where((c) => c.id != parent.id),
                updatedParent
              ],
            );
            nodeStack[j] = updatedAncestor;
            parent = updatedAncestor;
            updatedParent = updatedAncestor;
          }
          rootNode = nodeStack[0];
          print('递归更新后根节点，子节点数量: ${rootNode.children.length}');
        }
        // 将新节点压入栈
        nodeStack.add(node);
        print('将节点 ${node.text} 压入栈，当前栈深度: ${nodeStack.length}');
      } else {
        // 处理列表项
        final listMatch = RegExp(r'^(\s*)([-*+]\s+|(\d+\.\s+))(.+)$').firstMatch(line);
        if (listMatch != null) {
          final indent = listMatch.group(1)!.length;
          final text = listMatch.group(4)!.trim();
          // 根据当前栈顶节点的level来确定列表项的level
          final parentLevel = nodeStack.isNotEmpty ? nodeStack.last.level : 0;
          final level = parentLevel + 1;
          print('发现列表项: $text (indent: $indent, parentLevel: $parentLevel, level: $level)');
          final node = MindMapNode(
            id: 'node_${i}_list_$level',
            text: cleanMarkdownText(text),
            level: level,
          );
          print('当前栈深度: ${nodeStack.length}');
          print('栈顶节点: ${nodeStack.last.text} (level: ${nodeStack.last.level})');
          // 将节点添加到当前栈顶的父节点
          if (nodeStack.isNotEmpty) {
            var parent = nodeStack.last;
            print('找到父节点: ${parent.text} (level: ${parent.level})');
            var updatedParent = parent.copyWith(
              children: [...parent.children, node],
            );
            print('更新父节点 ${parent.text}，子节点数量: ${updatedParent.children.length}');
            nodeStack[nodeStack.length - 1] = updatedParent;
            // 递归向上更新祖先链
            for (int j = nodeStack.length - 2; j >= 0; j--) {
              final ancestor = nodeStack[j];
              final updatedAncestor = ancestor.copyWith(
                children: [
                  ...ancestor.children.where((c) => c.id != parent.id),
                  updatedParent
                ],
              );
              nodeStack[j] = updatedAncestor;
              parent = updatedAncestor;
              updatedParent = updatedAncestor;
            }
            rootNode = nodeStack[0];
            print('递归更新后根节点，子节点数量: ${rootNode.children.length}');
          }
          // 列表项不压入栈，因为它们不是父节点
          print('列表项 ${node.text} 不压入栈，作为叶子节点');
        } else {
          // 处理普通文本段落 - 作为当前栈顶节点的子节点
          if (nodeStack.isNotEmpty) {
            print('发现普通文本: $line');
            final node = MindMapNode(
              id: 'node_${i}_text',
              text: cleanMarkdownText(line),
              level: nodeStack.last.level + 1,
            );
            var parent = nodeStack.last;
            print('添加到父节点: ${parent.text} (level: ${parent.level})');
            var updatedParent = parent.copyWith(
              children: [...parent.children, node],
            );
            print('更新父节点 ${parent.text}，子节点数量: ${updatedParent.children.length}');
            nodeStack[nodeStack.length - 1] = updatedParent;
            // 递归向上更新祖先链
            for (int j = nodeStack.length - 2; j >= 0; j--) {
              final ancestor = nodeStack[j];
              final updatedAncestor = ancestor.copyWith(
                children: [
                  ...ancestor.children.where((c) => c.id != parent.id),
                  updatedParent
                ],
              );
              nodeStack[j] = updatedAncestor;
              parent = updatedAncestor;
              updatedParent = updatedAncestor;
            }
            rootNode = nodeStack[0];
            print('递归更新后根节点，子节点数量: ${rootNode.children.length}');
          }
        }
      }
    }
    print('=== 解析完成 ===');
    print('最终根节点: ${rootNode.text}');
    print('根节点子节点数量: ${rootNode.children.length}');
    _printNodeTree(rootNode, 0);
    return rootNode;
  }

  // 打印节点树结构的辅助函数
  static void _printNodeTree(MindMapNode node, int depth) {
    final indent = '  ' * depth;
    print('$indent${node.text} (level: ${node.level}, children: ${node.children.length})');
    for (final child in node.children) {
      _printNodeTree(child, depth + 1);
    }
  }

  static String cleanMarkdownText(String text) {
    // 移除Markdown语法，保留纯文本
    return text
        .replaceAll(RegExp(r'[*_]{1,2}([^*_]+)[*_]{1,2}'), r'$1') // 粗体和斜体
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1') // 行内代码
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1') // 链接
        .replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), r'$1') // 图片
        .replaceAll(RegExp(r'^#{1,6}\s+'), '') // 标题标记
        .replaceAll(RegExp(r'^[-*+]\s+'), '') // 无序列表标记
        .replaceAll(RegExp(r'^\d+\.\s+'), '') // 有序列表标记
        .trim();
  }
} 
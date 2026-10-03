/// 转写编辑草稿存取（PRD-02 F2-1 防丢失）。
///
/// 存 Hive basicBox：
/// - 编辑草稿 `trans_draft_{fileId}_{recordId}` → {text, updatedAt}
/// - 转写进行中任务 `trans_pending_{fileId}` → taskId（冷启恢复轮询）
///
/// 保存成功即清草稿；超过 [draftTtl] 的草稿视为过期，读取时返回
/// null 并顺手清除。Box 可注入以便单测。
library;

import 'package:hive/hive.dart';

class TransDraftStore {
  TransDraftStore({Box<dynamic>? box}) : _injectedBox = box;

  /// PRD-02 F2-1：草稿保留 24 小时。
  static const Duration draftTtl = Duration(hours: 24);

  static const String _draftPrefix = 'trans_draft_';
  static const String _pendingPrefix = 'trans_pending_';

  final Box<dynamic>? _injectedBox;

  Box<dynamic>? get _box {
    if (_injectedBox != null) return _injectedBox;
    if (Hive.isBoxOpen('basicBox')) return Hive.box('basicBox');
    return null;
  }

  static String draftKey(String fileId, String recordId) =>
      '$_draftPrefix${fileId}_$recordId';

  static String pendingKey(String fileId) => '$_pendingPrefix$fileId';

  // ------------------------------------------------------------------
  // 分段编辑草稿
  // ------------------------------------------------------------------

  void saveDraft({
    required String fileId,
    required String recordId,
    required String text,
  }) {
    _box?.put(draftKey(fileId, recordId), {
      'text': text,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 未过期草稿文本；无草稿或已过期（顺手清除）返回 null。
  String? loadFreshDraft({required String fileId, required String recordId}) {
    final box = _box;
    if (box == null) return null;
    final raw = box.get(draftKey(fileId, recordId));
    if (raw is! Map) return null;
    final updatedAtMs = (raw['updatedAt'] as num?)?.toInt() ?? 0;
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(updatedAtMs));
    if (age >= draftTtl) {
      clearDraft(fileId: fileId, recordId: recordId);
      return null;
    }
    return raw['text']?.toString();
  }

  void clearDraft({required String fileId, required String recordId}) {
    _box?.delete(draftKey(fileId, recordId));
  }

  // ------------------------------------------------------------------
  // 转写进行中任务（冷启恢复）
  // ------------------------------------------------------------------

  void savePendingTranscribe({required String fileId, required String taskId}) {
    _box?.put(pendingKey(fileId), {
      'taskId': taskId,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  String? loadPendingTranscribeTaskId({required String fileId}) {
    final box = _box;
    if (box == null) return null;
    final raw = box.get(pendingKey(fileId));
    if (raw is! Map) return null;
    final taskId = raw['taskId']?.toString() ?? '';
    return taskId.isEmpty ? null : taskId;
  }

  void clearPendingTranscribe({required String fileId}) {
    _box?.delete(pendingKey(fileId));
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:dting/core/services/trans_draft_store.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;
  late TransDraftStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('draft_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox('draft_test_box');
    store = TransDraftStore(box: box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('TransDraftStore 分段草稿', () {
    test('保存后可读回，清除后为空', () {
      store.saveDraft(
        fileId: 'f1',
        recordId: 'r1',
        text: '修正后的文字',
      );
      expect(
        store.loadFreshDraft(fileId: 'f1', recordId: 'r1'),
        '修正后的文字',
      );

      store.clearDraft(fileId: 'f1', recordId: 'r1');
      expect(store.loadFreshDraft(fileId: 'f1', recordId: 'r1'), isNull);
    });

    test('不同分段互不干扰', () {
      store.saveDraft(fileId: 'f1', recordId: 'r1', text: 'A');
      store.saveDraft(fileId: 'f1', recordId: 'r2', text: 'B');
      expect(store.loadFreshDraft(fileId: 'f1', recordId: 'r1'), 'A');
      expect(store.loadFreshDraft(fileId: 'f1', recordId: 'r2'), 'B');

      store.clearDraft(fileId: 'f1', recordId: 'r1');
      expect(store.loadFreshDraft(fileId: 'f1', recordId: 'r1'), isNull);
      expect(store.loadFreshDraft(fileId: 'f1', recordId: 'r2'), 'B');
    });

    test('超过 24h 的草稿视为过期并顺手清除', () {
      final staleMs = DateTime.now()
          .subtract(const Duration(hours: 25))
          .millisecondsSinceEpoch;
      box.put(TransDraftStore.draftKey('f1', 'r1'), {
        'text': '旧草稿',
        'updatedAt': staleMs,
      });

      expect(store.loadFreshDraft(fileId: 'f1', recordId: 'r1'), isNull);
      expect(box.get(TransDraftStore.draftKey('f1', 'r1')), isNull);
    });

    test('24h 内的旧草稿仍可恢复', () {
      final recentMs = DateTime.now()
          .subtract(const Duration(hours: 23))
          .millisecondsSinceEpoch;
      box.put(TransDraftStore.draftKey('f1', 'r1'), {
        'text': '近期草稿',
        'updatedAt': recentMs,
      });
      expect(store.loadFreshDraft(fileId: 'f1', recordId: 'r1'), '近期草稿');
    });

    test('脏数据不抛异常', () {
      box.put(TransDraftStore.draftKey('f1', 'r1'), 'not-a-map');
      box.put(TransDraftStore.draftKey('f1', 'r2'), {'text': 123});
      expect(store.loadFreshDraft(fileId: 'f1', recordId: 'r1'), isNull);
      // updatedAt 缺失按 0 处理 → 过期
      expect(store.loadFreshDraft(fileId: 'f1', recordId: 'r2'), isNull);
    });
  });

  group('TransDraftStore 转写进行中任务', () {
    test('保存/读取/清除 pending taskId', () {
      expect(store.loadPendingTranscribeTaskId(fileId: 'f1'), isNull);

      store.savePendingTranscribe(fileId: 'f1', taskId: 'task-42');
      expect(store.loadPendingTranscribeTaskId(fileId: 'f1'), 'task-42');

      store.clearPendingTranscribe(fileId: 'f1');
      expect(store.loadPendingTranscribeTaskId(fileId: 'f1'), isNull);
    });

    test('空 taskId 存储读回为 null', () {
      box.put(TransDraftStore.pendingKey('f1'), {'taskId': ''});
      expect(store.loadPendingTranscribeTaskId(fileId: 'f1'), isNull);
    });
  });
}

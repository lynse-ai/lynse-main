import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dting/core/services/polling_task.dart';

void main() {
  group('PollingTask', () {
    test('按固定间隔探测，完成后触发 onComplete 并停止', () {
      fakeAsync((async) {
        var probes = 0;
        var completed = 0;
        final task = PollingTask(
          probe: () async => Future.value(++probes >= 3),
          onComplete: () => completed++,
        )..start();

        async.elapse(const Duration(seconds: 5));
        expect(probes, 1);
        async.elapse(const Duration(seconds: 5));
        expect(probes, 2);
        async.elapse(const Duration(seconds: 5));
        expect(probes, 3);
        expect(completed, 1);
        expect(task.isRunning, isFalse);

        // 完成后不再探测
        async.elapse(const Duration(minutes: 1));
        expect(probes, 3);
      });
    });

    test('连续失败达阈值后退避到长间隔', () {
      fakeAsync((async) {
        var errors = 0;
        final task = PollingTask(
          probe: () async => throw StateError('down'),
          onError: (_) => errors++,
        )..start();

        // 三次失败各间隔 5s
        async.elapse(const Duration(seconds: 15, milliseconds: 1));
        expect(errors, 3);
        // 退避 15s：10s 内不应有第 4 次探测
        async.elapse(const Duration(seconds: 10));
        expect(errors, 3);
        async.elapse(const Duration(seconds: 5, milliseconds: 1));
        expect(errors, 4);
        task.dispose();
      });
    });

    test('成功探测（未完成）重置连续失败计数', () {
      fakeAsync((async) {
        var calls = 0;
        final task = PollingTask(
          probe: () async {
            calls++;
            // 1,2 失败；3,4 成功但未完成（false）；5 失败
            if (calls <= 2) throw StateError('down');
            if (calls == 5) throw StateError('down');
            return false;
          },
        )..start();

        async.elapse(const Duration(seconds: 15, milliseconds: 1));
        expect(calls, 3); // 两次失败 + 一次成功探测
        // 计数已重置：t=20、25 继续按 5s 短间隔探测
        async.elapse(const Duration(seconds: 10, milliseconds: 1));
        expect(calls, 5);
        task.dispose();
      });
    });

    test('pause 停止心跳，resume 恢复', () {
      fakeAsync((async) {
        var probes = 0;
        final task = PollingTask(
          probe: () async => Future.value(++probes >= 99),
        )..start();

        task.pause();
        async.elapse(const Duration(seconds: 30));
        expect(probes, 0);

        task.resume();
        async.elapse(const Duration(seconds: 5, milliseconds: 1));
        expect(probes, 1);
        task.dispose();
      });
    });

    test('探测未返回时不并发堆积（返回后才安排下一轮）', () {
      fakeAsync((async) {
        var probes = 0;
        final c = Completer<bool>();
        final task = PollingTask(
          probe: () {
            probes++;
            return c.future;
          },
        )..start();

        // 第一轮挂起 30s：期间不应有任何新的探测被发起
        async.elapse(const Duration(seconds: 30));
        expect(probes, 1);

        c.complete(false);
        async.flushMicrotasks();
        // 上一轮返回后才安排 5s 后的下一轮
        async.elapse(const Duration(seconds: 5, milliseconds: 1));
        expect(probes, 2);
        task.dispose();
      });
    });

    test('dispose 后不再探测、不再回调', () {
      fakeAsync((async) {
        var probes = 0;
        var completed = 0;
        final task = PollingTask(
          probe: () async {
            probes++;
            return probes >= 2;
          },
          onComplete: () => completed++,
        )..start();

        async.elapse(const Duration(seconds: 5));
        expect(probes, 1);
        task.dispose();
        async.elapse(const Duration(minutes: 5));
        expect(probes, 1);
        expect(completed, 0);
      });
    });

    test('对已 dispose 实例 start/pause 是空操作', () {
      final task = PollingTask(probe: () async => true)..dispose();
      task.start();
      task.pause();
      task.resume();
      expect(task.isRunning, isFalse);
    });
  });
}

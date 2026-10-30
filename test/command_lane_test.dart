import 'dart:async';

import 'package:dting/core/hardware/ble_device_adapter.dart';
import 'package:dting/core/hardware/command_lane.dart';
import 'package:dting/core/hardware/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// 命令车道的语义就三条：FIFO、一次一条、失败不卡队。
/// 这三条对应的是卡上的真实约束（多条 `*DEV#` 合并、会话类命令被打断就作废）。
void main() {
  group('CommandLane', () {
    test('一次只跑一条，且按提交顺序（FIFO）', () async {
      final lane = CommandLane(label: 'test');
      final log = <String>[];
      var concurrent = 0;
      var maxConcurrent = 0;

      Future<void> task(String name, int delayMs) => lane.run(name, () async {
            concurrent++;
            maxConcurrent = concurrent > maxConcurrent ? concurrent : maxConcurrent;
            log.add('begin:$name');
            await Future<void>.delayed(Duration(milliseconds: delayMs));
            log.add('end:$name');
            concurrent--;
          });

      // 故意让第一条最慢：如果是并发，日志会交错；如果是队列，end:A 一定在 begin:B 之前。
      await Future.wait([
        task('A', 60),
        task('B', 10),
        task('C', 1),
      ]);

      expect(maxConcurrent, 1, reason: '同一时刻只能有一条命令在飞');
      expect(log, [
        'begin:A', 'end:A',
        'begin:B', 'end:B',
        'begin:C', 'end:C',
      ]);
    });

    test('一条抛错不会卡死后面的命令，错误只回到它自己的调用方', () async {
      final lane = CommandLane(label: 'test');
      final done = <String>[];

      final bad = lane.run<void>('bad', () async => throw StateError('设备拒了'));
      final good1 = lane.run<void>('good1', () async => done.add('good1'));
      final good2 = lane.run<void>('good2', () async => done.add('good2'));

      await expectLater(bad, throwsStateError);
      await good1;
      await good2;
      expect(done, ['good1', 'good2'], reason: '前一条失败不能把队列一起带走');
      expect(lane.inFlight, isNull);
      expect(lane.waiting, 0);
    });

    test('isBusy/waiting 能反映排队深度（UI 需要显示「排队中」）', () async {
      final lane = CommandLane(label: 'test');
      final gate = Completer<void>();
      final first = lane.run<void>('first', () => gate.future);
      final second = lane.run<void>('second', () async {});

      // run() 是同步入队的：此刻两条都在队里，第一条还没真正开始跑（microtask 之后才轮到它）。
      expect(lane.isBusy, isTrue);
      expect(lane.waiting, 2);
      await Future<void>.value();
      expect(lane.inFlight, 'first');
      expect(lane.waiting, 1);

      gate.complete();
      await first;
      await second;
      expect(lane.isBusy, isFalse);
      expect(lane.waiting, 0);
    });
  });

  group('ResourceArbiter（同类资源也不许重入）', () {
    test('同一个资源第二次 acquire 要抛 resourceBusy——旧实现会放行', () {
      final arbiter = ResourceArbiter();
      arbiter.acquire(ExclusiveResource.fileTransfer);
      expect(
        () => arbiter.acquire(ExclusiveResource.fileTransfer),
        throwsA(isA<HardwareException>()
            .having((e) => e.code, 'code', HardwareErrorCode.resourceBusy)),
        reason: '两次并发 fileTransfer 正是「两条流压在卡上」的入口',
      );
      arbiter.release(ExclusiveResource.fileTransfer);
      arbiter.acquire(ExclusiveResource.fileTransfer); // 释放后可以再拿
      expect(arbiter.held, ExclusiveResource.fileTransfer);
    });

    test('不同资源互斥，释放别的资源不会误放当前持有者', () {
      final arbiter = ResourceArbiter();
      arbiter.acquire(ExclusiveResource.recording);
      expect(() => arbiter.acquire(ExclusiveResource.fileTransfer), throwsA(isA<HardwareException>()));
      arbiter.release(ExclusiveResource.fileTransfer); // 不是自己持有的，忽略
      expect(arbiter.held, ExclusiveResource.recording);
      arbiter.release(ExclusiveResource.recording);
      expect(arbiter.held, isNull);
    });
  });
}

/// TransferTarget 的落盘/校验契约测试。
///
/// 这一层决定了「一次传输能不能被当成一条录音」，是断点与校验语义的地基，
/// 因此用真实临时文件验证，不做 mock。
library;

import 'dart:io';

import 'package:dting/core/hardware/models.dart';
import 'package:dting/core/hardware/transfer_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lynse_transfer_target');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  TransferTarget target([String name = 'rec_001.wav']) =>
      TransferTarget.inDirectory(dir, name, prefix: 'xyrix_dl_');

  /// 模拟一次收流：把 [chunks] 写进断点文件，返回未关闭的 sink
  Future<IOSink> writeChunks(TransferTarget t, List<List<int>> chunks) async {
    final sink = t.partFile.openWrite();
    for (final c in chunks) {
      sink.add(c);
    }
    return sink;
  }

  group('resumeOffset', () {
    test('没有断点文件时为 0', () async {
      expect(await target().resumeOffset(), 0);
    });

    test('断点文件的字节数就是续传偏移', () async {
      final t = target();
      await t.partFile.writeAsBytes(List.filled(1024, 0x41));
      expect(await t.resumeOffset(), 1024);
    });

    test('append 模式写入不破坏已有断点字节', () async {
      final t = target();
      await t.partFile.writeAsBytes(List.filled(500, 0x41));
      final sink = t.partFile.openWrite(mode: FileMode.append);
      sink.add(List.filled(250, 0x42));
      await sink.flush();
      await sink.close();
      expect(await t.resumeOffset(), 750);
    });
  });

  group('finalize', () {
    test('字节数相符：断点提升为正式文件，判定 verified', () async {
      final t = target();
      final payload = List.filled(4096, 0x7F);
      final outcome = await t.finalize(await writeChunks(t, [payload]), 4096);

      expect(outcome.integrity, TransferIntegrity.verified);
      expect(outcome.trusted, isTrue);
      expect(outcome.expectedBytes, 4096);
      expect(outcome.actualBytes, 4096);
      expect(File(outcome.filePath).path, t.finalFile.path);
      expect(await t.finalFile.exists(), isTrue);
      expect(await t.partFile.exists(), isFalse);
      expect(await t.finalFile.length(), 4096);
    });

    test('少收：判定 sizeMismatch，断点保留且不产出正式文件', () async {
      final t = target();
      final outcome = await t.finalize(
          await writeChunks(t, [List.filled(100, 0x01)]), 512);

      expect(outcome.integrity, TransferIntegrity.sizeMismatch);
      expect(outcome.trusted, isFalse);
      expect(outcome.actualBytes, 100);
      expect(await t.finalFile.exists(), isFalse);
      // 断点必须留着，WiFi 通道的 0x46 续传以它为起点
      expect(await t.partFile.exists(), isTrue);
      expect(await t.resumeOffset(), 100);
    });

    test('期望大小未知：unverified，不做改名也不报错', () async {
      final t = target();
      final outcome =
          await t.finalize(await writeChunks(t, [List.filled(64, 0x02)]), 0);

      expect(outcome.integrity, TransferIntegrity.unverified);
      expect(outcome.trusted, isFalse);
      expect(outcome.expectedBytes, 0);
      expect(await t.finalFile.exists(), isFalse);
    });

    test('分多条通知交错到达时按总字节校验', () async {
      final t = target();
      final outcome = await t.finalize(
        await writeChunks(t, [
          List.filled(300, 0xAA),
          List.filled(17, 0xBB),
          List.filled(683, 0xCC),
        ]),
        1000,
      );
      expect(outcome.integrity, TransferIntegrity.verified);
      expect(outcome.actualBytes, 1000);
    });

    test('同名的旧正式文件被本次校验通过的结果覆盖', () async {
      final t = target();
      await t.finalFile.writeAsBytes(List.filled(9, 0x00));
      final outcome =
          await t.finalize(await writeChunks(t, [List.filled(20, 0x01)]), 20);

      expect(outcome.integrity, TransferIntegrity.verified);
      expect(await t.finalFile.length(), 20);
    });

    test('断点文件不存在时不得产出虚假的 verified 结果', () async {
      final t = target();
      final sink = t.partFile.openWrite();
      await sink.flush();
      await sink.close();
      await t.partFile.delete();

      final outcome = await t.finalize(sink, 0);
      expect(outcome.integrity, TransferIntegrity.unverified);
      expect(outcome.actualBytes, 0);
    });
  });

  group('discard', () {
    test('清掉断点，续传偏移随之归零', () async {
      final t = target();
      await t.partFile.writeAsBytes(List.filled(300, 0x03));
      await t.discard();

      expect(await t.partFile.exists(), isFalse);
      expect(await t.resumeOffset(), 0);
    });

    test('断点不存在时静默返回', () async {
      final t = target();
      await expectLater(t.discard(), completes);
    });
  });

  test('不同设备文件名互不干扰', () async {
    final a = target('rec_a.wav');
    final b = target('rec_b.wav');
    await a.finalize(await writeChunks(a, [List.filled(8, 0x01)]), 8);
    await b.finalize(await writeChunks(b, [List.filled(4, 0x02)]), 9);

    expect(await a.finalFile.exists(), isTrue);
    expect(await b.finalFile.exists(), isFalse);
    expect(await b.partFile.exists(), isTrue);
  });
}

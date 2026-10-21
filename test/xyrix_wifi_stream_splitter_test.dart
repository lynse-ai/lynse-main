/// XyrixWifiStreamSplitter 单元测试。
///
/// 判据来自 2026-10-21 真机：设备经 TCP 推来的是文件原始字节，末尾追加
/// 20 字节 `sendfile finish!` + 4×NUL。当时这 20 字节被算进文件长度，
/// 一次**已经成功**的快传（77,952 B 与蓝牙下载逐字节相同）被自己判成
/// 「数据流被污染」。这些用例锁住切分规则，防止再犯。
library;

import 'dart:typed_data';

import 'package:dting/core/hardware/xyrix/xyrix_wifi_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

/// 把 data 按 sizes 循环切片依次喂进 splitter，返回拼起来的「文件字节」
Uint8List _feedInChunks(XyrixWifiStreamSplitter s, List<int> data, List<int> sizes) {
  final out = BytesBuilder(copy: false);
  var pos = 0;
  var i = 0;
  while (pos < data.length) {
    final n = sizes[i % sizes.length];
    final end = (pos + n) > data.length ? data.length : pos + n;
    out.add(s.feed(Uint8List.fromList(data.sublist(pos, end))));
    pos = end;
    i++;
  }
  // 流结束时可能还压着「标记前缀」，用一次空喂不会冲出来，测试里显式收尾
  return out.toBytes();
}

void main() {
  final trailer = XyrixWifiStreamSplitter.trailer;

  group('XyrixWifiStreamSplitter', () {
    test('标记长度就是真机看到的 20 字节 sendfile finish!+NUL', () {
      expect(trailer.length, 20);
      expect(String.fromCharCodes(trailer.take(16)), 'sendfile finish!');
      expect(trailer.sublist(16), <int>[0, 0, 0, 0]);
    });

    test('整段一次喂入：只吐文件字节，标记之后的一律丢弃', () {
      final fileBytes = List<int>.generate(1000, (i) => (i * 7) & 0xFF);
      final stream = <int>[
        ...fileBytes,
        ...trailer,
        // 断点越界时设备还会再回几轮标记，一并喂进来
        ...trailer,
        ...trailer,
      ];
      final s = XyrixWifiStreamSplitter();
      final got = s.feed(stream);
      expect(got, equals(fileBytes));
      expect(s.finished, isTrue);
      // 标记之后再来数据也不许写盘
      expect(s.feed(List<int>.filled(64, 0x41)), isEmpty);
    });

    test('标记被 TCP 从任意位置切开都能认出来', () {
      final fileBytes = List<int>.generate(512, (i) => (i * 3 + 1) & 0xFF);
      final stream = <int>[...fileBytes, ...trailer];
      for (var cut = 1; cut < trailer.length; cut++) {
        final s = XyrixWifiStreamSplitter();
        final out = BytesBuilder(copy: false);
        out.add(s.feed(Uint8List.fromList(stream.sublist(0, fileBytes.length + cut))));
        out.add(s.feed(Uint8List.fromList(stream.sublist(fileBytes.length + cut))));
        expect(out.toBytes(), equals(fileBytes), reason: '切点 cut=$cut');
        expect(s.finished, isTrue, reason: '切点 cut=$cut 应认出标记');
      }
    });

    test('各种块大小下文件字节一个不少、一个不多', () {
      final fileBytes = List<int>.generate(4096, (i) => (i ^ 0x5A) & 0xFF);
      final stream = <int>[...fileBytes, ...trailer];
      for (final sizes in [
        [1],
        [7],
        [19],
        [20],
        [21],
        [1, 2, 3, 5, 8, 13, 21, 34],
        [1460],
        [4096],
      ]) {
        final s = XyrixWifiStreamSplitter();
        final got = _feedInChunks(s, stream, sizes);
        expect(got, equals(fileBytes), reason: '块大小 $sizes');
        expect(s.finished, isTrue, reason: '块大小 $sizes');
      }
    });

    test('纯文件字节（未见标记）不会误判完成', () {
      final s = XyrixWifiStreamSplitter();
      final got = s.feed(List<int>.filled(100, 0x33));
      expect(got.length, 100 - (trailer.length - 1)); // 尾巴留待下一轮
      expect(s.finished, isFalse);
    });

    // 已知局限，写死在这里而不是等人踩：设备只把标记放在流尾，
    // 而我们无法区分「文件内容里就有这串字节」和「这是标记」。
    // 兜底是 TransferTarget.finalize 的字节数核对——真提前截断了，
    // 大小对不上就判 sizeMismatch，不会把残缺文件当成功入库。
    test('文件内容本身含标记串会被提前截断（由大小核对兜底）', () {
      final s = XyrixWifiStreamSplitter();
      final data = <int>[...List<int>.filled(10, 1), ...trailer, ...List<int>.filled(10, 2)];
      final got = s.feed(data);
      expect(got, equals(List<int>.filled(10, 1)));
      expect(s.finished, isTrue);
      expect(got.length, lessThan(data.length));
    });
  });
}

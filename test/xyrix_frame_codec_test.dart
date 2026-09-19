/// Xyrix 协议帧编解码单元测试。
///
/// 注意：厂商文档 §8.5 中 Telink 启动帧示例 `FF 55 AA 02 00 08 00`
/// 与「长度 = 1 + N」规则存在自相矛盾（按规则应为 FF 55 AA 03 00 08 00），
/// 本实现以文档正文规则（长度 = 1 + N）为准，
/// TODO(厂商确认): 真机联调时核实长度字段语义。
library;

import 'dart:typed_data';

import 'package:dting/hardware/xyrix/xyrix_commands.dart';
import 'package:dting/hardware/xyrix/xyrix_frame_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encode', () {
    test('无数据命令（查询电量 0x01）', () {
      final frame = XyrixFrameCodec.encode(XyrixCommands.queryBattery);
      expect(frame, [0xFF, 0x55, 0xAA, 0x01, 0x01]);
    });

    test('带数据命令（改蓝牙名）', () {
      final frame = XyrixFrameCodec.encode(0x02, [0x01, 0x64, 0x01]);
      expect(frame, [0xFF, 0x55, 0xAA, 0x04, 0x02, 0x01, 0x64, 0x01]);
    });

    test('命令码越界抛异常', () {
      expect(() => XyrixFrameCodec.encode(0x100), throwsA(isA<XyrixFrameException>()));
    });

    test('数据超长抛异常', () {
      expect(
        () => XyrixFrameCodec.encode(0x01, List.filled(255, 0x00)),
        throwsA(isA<XyrixFrameException>()),
      );
    });
  });

  group('decode', () {
    test('完整单帧', () {
      final (frames, rest) = XyrixFrameCodec.decode(
        Uint8List.fromList([0xFF, 0x55, 0xAA, 0x03, 0x01, 0x64, 0x01]),
      );
      expect(frames, hasLength(1));
      expect(frames.first.command, 0x01);
      expect(frames.first.data, [0x64, 0x01]);
      expect(rest, isEmpty);
    });

    test('半包粘包：先到半帧再到剩余字节', () {
      final full = [0xFF, 0x55, 0xAA, 0x03, 0x01, 0x64, 0x01];
      final (f1, rest1) = XyrixFrameCodec.decode(Uint8List.fromList(full.sublist(0, 5)));
      expect(f1, isEmpty);
      final (f2, rest2) = XyrixFrameCodec.decode(
        Uint8List.fromList([...rest1, ...full.sublist(5)]),
      );
      expect(f2, hasLength(1));
      expect(f2.first.data, [0x64, 0x01]);
      expect(rest2, isEmpty);
    });

    test('多帧连发 + 前导垃圾字节', () {
      final frameA = XyrixFrameCodec.encode(0x01);
      final frameB = XyrixFrameCodec.encode(0x17);
      final buffer = [0x00, 0x11, ...frameA, ...frameB];
      final (frames, rest) = XyrixFrameCodec.decode(Uint8List.fromList(buffer));
      expect(frames.map((f) => f.command).toList(), [0x01, 0x17]);
      expect(rest, isEmpty);
    });

    test('帧头前缀是数据内容时不会误切', () {
      // 0xFF 0x55 0xAA 出现在长度不足处，应等待更多字节而不是解出错误帧
      final (frames, rest) = XyrixFrameCodec.decode(
        Uint8List.fromList([0xFF, 0x55, 0xAA]),
      );
      expect(frames, isEmpty);
      expect(rest, [0xFF, 0x55, 0xAA]);
    });
  });

  group('data helpers', () {
    test('timeData 大端序', () {
      final data = XyrixFrameCodec.timeData(
          DateTime.fromMillisecondsSinceEpoch(0x01020304 * 1000, isUtc: true));
      expect(data, [0x01, 0x02, 0x03, 0x04]);
    });

    test('wifiResumeData = 路径 + 4 字节大端断点', () {
      final data = XyrixFrameCodec.wifiResumeData('0:/a.wav', 0x01020304);
      expect(data.sublist(data.length - 4), [0x01, 0x02, 0x03, 0x04]);
      expect(String.fromCharCodes(data.sublist(0, data.length - 4)), '0:/a.wav');
    });
  });
}

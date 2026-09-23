/// Xyrix 协议帧编解码单元测试。
///
/// 长度字节语义以 2026-09 真机联调实测为准：长度 = N（数据字节数），
/// 帧总长 = 5 + N。测试用例直接使用真机抓包字节。
/// （厂商 API_Reference.md 的「长度 = 1 + N」与设备实际行为不符，勿改回。）
library;

import 'dart:typed_data';

import 'package:dting/hardware/xyrix/xyrix_commands.dart';
import 'package:dting/hardware/xyrix/xyrix_frame_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encode', () {
    test('无数据命令（查询电量 0x01）长度字节 = 0', () {
      final frame = XyrixFrameCodec.encode(XyrixCommands.queryBattery);
      expect(frame, [0xFF, 0x55, 0xAA, 0x00, 0x01]);
    });

    test('带数据命令（改蓝牙名）长度字节 = N', () {
      final frame = XyrixFrameCodec.encode(0x02, [0x01, 0x64, 0x01]);
      expect(frame, [0xFF, 0x55, 0xAA, 0x03, 0x02, 0x01, 0x64, 0x01]);
    });

    test('同步时间：4 字节大端时间戳', () {
      final data = XyrixFrameCodec.timeData(
          DateTime.fromMillisecondsSinceEpoch(0x01020304 * 1000, isUtc: true));
      final frame = XyrixFrameCodec.encode(XyrixCommands.syncTime, data);
      expect(frame,
          [0xFF, 0x55, 0xAA, 0x04, 0x13, 0x01, 0x02, 0x03, 0x04]);
    });

    test('文件列表查询：路径字符串', () {
      final frame = XyrixFrameCodec.encode(
          XyrixCommands.fileList, XyrixFrameCodec.pathData('0:/ .wav'));
      expect(frame, [0xFF, 0x55, 0xAA, 0x08, 0x05, ...'0:/ .wav'.codeUnits]);
    });

    test('命令码越界抛异常', () {
      expect(() => XyrixFrameCodec.encode(0x100), throwsA(isA<XyrixFrameException>()));
    });

    test('数据超长抛异常', () {
      expect(
        () => XyrixFrameCodec.encode(0x01, List.filled(256, 0x00)),
        throwsA(isA<XyrixFrameException>()),
      );
    });
  });

  group('decode（真机抓包字节）', () {
    test('电量响应：2 字节数据 + 紧跟 0x2F ACK（同一通知内粘包）', () {
      // 真机实测：电量 98%、未充电
      final (frames, rest) = XyrixFrameCodec.decode(
        Uint8List.fromList(
            [0xFF, 0x55, 0xAA, 0x02, 0x01, 0x62, 0x00, 0xFF, 0x55, 0xAA, 0x00, 0x2F]),
      );
      expect(frames, hasLength(2));
      expect(frames[0].command, 0x01);
      expect(frames[0].data, [0x62, 0x00]); // 电量分支要求 data.length >= 2
      expect(frames[1].command, 0x2F);
      expect(frames[1].data, isEmpty);
      expect(rest, isEmpty);
    });

    test('版本响应：27 字节版本串 + 9 字节补零 + ACK', () {
      final raw = Uint8List.fromList([
        ...[0xFF, 0x55, 0xAA, 0x1B, 0x17],
        ...'2025/01/01-12:00:00 v2.0.13'.codeUnits,
        ...List.filled(9, 0x00),
        ...[0xFF, 0x55, 0xAA, 0x00, 0x2F],
      ]);
      final (frames, rest) = XyrixFrameCodec.decode(raw);
      expect(frames, hasLength(2));
      expect(frames[0].command, 0x17);
      expect(String.fromCharCodes(frames[0].data), '2025/01/01-12:00:00 v2.0.13');
      expect(frames[1].command, 0x2F);
      expect(rest, isEmpty);
    });

    test('半包粘包：帧分多次到达', () {
      final full = [0xFF, 0x55, 0xAA, 0x02, 0x01, 0x62, 0x00];
      final (f1, rest1) = XyrixFrameCodec.decode(Uint8List.fromList(full.sublist(0, 5)));
      expect(f1, isEmpty);
      final (f2, rest2) = XyrixFrameCodec.decode(
        Uint8List.fromList([...rest1, ...full.sublist(5)]),
      );
      expect(f2, hasLength(1));
      expect(f2.first.data, [0x62, 0x00]);
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

    test('仅有帧头/长度字节未到齐时等待更多数据', () {
      final (frames, rest) = XyrixFrameCodec.decode(
        Uint8List.fromList([0xFF, 0x55, 0xAA]),
      );
      expect(frames, isEmpty);
      expect(rest, [0xFF, 0x55, 0xAA]);
    });

    test('长度字节声明的数据未收齐时整帧保留', () {
      // 按长度=N 需 8 字节，只到了 7 字节 → 等待，不得误切
      final (frames, rest) = XyrixFrameCodec.decode(
        Uint8List.fromList([0xFF, 0x55, 0xAA, 0x03, 0x01, 0x62, 0x00]),
      );
      expect(frames, isEmpty);
      expect(rest, [0xFF, 0x55, 0xAA, 0x03, 0x01, 0x62, 0x00]);
    });
  });

  group('parseFileListLine（真机抓包明文行）', () {
    test('标准行：路径 + 字节数 + 秒数（固件输出带负号）', () {
      final r = XyrixFrameCodec.parseFileListLine(
          '0:/2026-09-21-09-57-34.wav -145976 B -3680 s');
      expect(r, isNotNull);
      expect(r!.path, '0:/2026-09-21-09-57-34.wav');
      expect(r.sizeBytes, 145976);
      expect(r.seconds, 3680);
    });

    test('大文件行', () {
      final r = XyrixFrameCodec.parseFileListLine(
          '0:/2026-09-18-13-51-35.wav -69927795 B -1830064 s');
      expect(r!.sizeBytes, 69927795);
      expect(r.seconds, 1830064);
    });

    test('非文件行返回 null', () {
      expect(XyrixFrameCodec.parseFileListLine('FF 55 AA 00 2F'), isNull);
      expect(XyrixFrameCodec.parseFileListLine(''), isNull);
      expect(XyrixFrameCodec.parseFileListLine('garbage line'), isNull);
    });
  });

  group('data helpers', () {
    test('wifiResumeData = 路径 + 4 字节大端断点', () {
      final data = XyrixFrameCodec.wifiResumeData('0:/a.wav', 0x01020304);
      expect(data.sublist(data.length - 4), [0x01, 0x02, 0x03, 0x04]);
      expect(String.fromCharCodes(data.sublist(0, data.length - 4)), '0:/a.wav');
    });
  });
}

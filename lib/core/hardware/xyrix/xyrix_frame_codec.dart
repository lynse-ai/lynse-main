/// Xyrix 协议帧编解码：`FF 55 AA [长度 1B] [命令码 1B] [数据 N 字节]`。
///
/// 长度字节 = N（数据字节数，不含命令码），帧总长 = 5 + N。
/// 2026-09 真机联调确认：设备响应（电量/版本/文件列表）一律按此约定，
/// 例如电量响应 `FF 55 AA 02 01 62 00`（长度=02，数据 2 字节）；
/// 长度 0 表示无数据帧（如 0x05 列表起始、0x2F 命令完成 ACK）。
/// 设备对下行命令的长度语义宽容（两种写法均接受），上行统一按 N 发送。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// 解析出的一帧
class XyrixFrame {
  final int command;
  final Uint8List data;

  const XyrixFrame(this.command, this.data);
}

/// 帧编解码异常
class XyrixFrameException implements Exception {
  final String message;
  XyrixFrameException(this.message);

  @override
  String toString() => 'XyrixFrameException($message)';
}

abstract final class XyrixFrameCodec {
  /// 帧头
  static const List<int> header = [0xFF, 0x55, 0xAA];

  /// 组帧：命令 + 数据 -> 完整帧字节
  static Uint8List encode(int command, [List<int> data = const []]) {
    if (command < 0 || command > 0xFF) {
      throw XyrixFrameException('命令码越界: $command');
    }
    if (data.length > 255) {
      throw XyrixFrameException('数据超长: ${data.length}');
    }
    final out = BytesBuilder();
    out.add(header);
    out.addByte(data.length); // 长度 = N
    out.addByte(command);
    out.add(data);
    return out.toBytes();
  }

  /// 从流式缓冲中解析出所有完整帧，返回 (帧列表, 剩余未完整字节)。
  ///
  /// 帧与帧之间允许夹杂非帧头字节（如版本响应尾部补零、文件列表明文），
  /// 这些字节会体现在返回的剩余缓冲里、随后被上层处理或丢弃；
  /// 长度字段异常时按最小帧长推进，保证本函数永不抛异常——
  /// 解码崩溃会连带取消通知订阅，导致后续所有响应静默丢失。
  static (List<XyrixFrame>, Uint8List) decode(Uint8List buffer) {
    final frames = <XyrixFrame>[];
    var offset = 0;
    while (true) {
      final headIdx = _findHeader(buffer, offset);
      if (headIdx < 0) {
        break;
      }
      if (buffer.length - headIdx < 4) {
        // 长度字节未到齐
        offset = headIdx;
        break;
      }
      final dataLen = buffer[headIdx + 3];
      final frameTotal = 5 + dataLen;
      if (buffer.length - headIdx < frameTotal) {
        // 帧未收完整。但若后面已出现下一个帧头，说明当前长度字节是坏的
        // （真机实测：时间同步 ACK 前混入杂散帧头 `FF 55 AA`，长度被误读为
        // 0xFF → 需 260 字节永收不齐 → 整条解析流被堵死，后续电量/版本/
        // 文件列表响应全部丢失）。跳到下一个帧头重新同步。
        final nextHead = _findHeader(buffer, headIdx + 1);
        if (nextHead < 0) {
          offset = headIdx;
          break;
        }
        debugPrint('[Xyrix] 坏长度字节 0x${dataLen.toRadixString(16)}，'
            '在 +$nextHead 处重新同步');
        offset = nextHead;
        continue;
      }
      final cmd = buffer[headIdx + 4];
      final data = Uint8List.sublistView(
        buffer,
        headIdx + 5,
        headIdx + frameTotal,
      );
      frames.add(XyrixFrame(cmd, Uint8List.fromList(data)));
      offset = headIdx + frameTotal;
    }
    final rest = offset >= buffer.length
        ? Uint8List(0)
        : Uint8List.sublistView(buffer, offset);
    return (frames, Uint8List.fromList(rest));
  }

  static int _findHeader(Uint8List buffer, int from) {
    for (var i = from; i <= buffer.length - 3; i++) {
      if (buffer[i] == header[0] &&
          buffer[i + 1] == header[1] &&
          buffer[i + 2] == header[2]) {
        return i;
      }
    }
    return -1;
  }

  /// 组「同步时间」数据：4 字节大端 Unix 时间戳
  static Uint8List timeData(DateTime time) {
    final sec = time.millisecondsSinceEpoch ~/ 1000;
    return Uint8List(4)
      ..[0] = (sec >> 24) & 0xFF
      ..[1] = (sec >> 16) & 0xFF
      ..[2] = (sec >> 8) & 0xFF
      ..[3] = sec & 0xFF;
  }

  /// 组「文件列表查询」数据：路径字符串（如 "0:/ .wav"）
  static Uint8List pathData(String path) =>
      Uint8List.fromList(utf8.encode(path));

  /// 解析文件列表明文行（0x05 起始帧与 0x2F 结束帧之间的内容），
  /// 格式：`0:/2026-09-21-09-57-34.wav -145976 B -3680 s`
  /// （字节数/秒数前的负号是设备固件的输出习惯，此处按绝对值取用）。
  /// 非文件行返回 null。
  static ({String path, int sizeBytes, int seconds})? parseFileListLine(
      String line) {
    final m =
        RegExp(r'^(\S+)\s+-(\d+)\s+B\s+-(\d+)\s+s\s*$').firstMatch(line.trim());
    if (m == null) return null;
    return (
      path: m.group(1)!,
      sizeBytes: int.parse(m.group(2)!),
      seconds: int.parse(m.group(3)!),
    );
  }

  /// 组「WiFi 断点续传」数据：路径 hex + 4 字节大端断点值
  static Uint8List wifiResumeData(String path, int resumeOffset) {
    final pathBytes = utf8.encode(path);
    final out = BytesBuilder();
    out.add(pathBytes);
    out.addByte((resumeOffset >> 24) & 0xFF);
    out.addByte((resumeOffset >> 16) & 0xFF);
    out.addByte((resumeOffset >> 8) & 0xFF);
    out.addByte(resumeOffset & 0xFF);
    return out.toBytes();
  }
}

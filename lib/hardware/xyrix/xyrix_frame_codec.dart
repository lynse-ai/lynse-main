/// Xyrix 协议帧编解码：`FF 55 AA [长度 1B] [命令码 1B] [数据 N 字节]`。
///
/// 长度字节 = 1 + 数据长度（命令码本身占 1 字节）。无校验和。
library;

import 'dart:convert';
import 'dart:typed_data';

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
    if (data.length > 255 - 1) {
      throw XyrixFrameException('数据超长: ${data.length}');
    }
    final out = BytesBuilder();
    out.add(header);
    out.addByte(data.length + 1); // 长度 = 命令码(1) + N
    out.addByte(command);
    out.add(data);
    return out.toBytes();
  }

  /// 从流式缓冲中解析出所有完整帧，返回 (帧列表, 剩余未完整字节)。
  static (List<XyrixFrame>, Uint8List) decode(Uint8List buffer) {
    final frames = <XyrixFrame>[];
    var offset = 0;
    while (true) {
      // 找帧头
      var headIdx = -1;
      for (var i = offset; i <= buffer.length - 3; i++) {
        if (buffer[i] == header[0] &&
            buffer[i + 1] == header[1] &&
            buffer[i + 2] == header[2]) {
          headIdx = i;
          break;
        }
      }
      if (headIdx < 0 || buffer.length - headIdx < 4) {
        // 无帧头 / 长度字节不完整
        break;
      }
      final len = buffer[headIdx + 3];
      final frameTotal = 5 + (len - 1); // 帧头3 + 长度1 + 命令1 + 数据N-1 = len+4
      if (buffer.length - headIdx < frameTotal) {
        // 帧未收完整
        offset = headIdx;
        break;
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

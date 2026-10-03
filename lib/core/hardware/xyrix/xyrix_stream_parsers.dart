/// Xyrix 通知流解析（无 BLE 依赖，可用真机抓包字节单元重放）。
///
/// 协议要点（2026-09 真机抓包实证）：
/// - 命令帧：`FF 55 AA [len][cmd][data]`
/// - 文件列表：`FF 55 AA 00 05` + 明文行 + `FF 55 AA 00 2F`
/// - 实时音频流：`FF 55 AA 00 54` 标记帧 + 自描述数据包
///   `[2B 长度 BE][4B 序列号 BE][载荷 N][2B CRC]`
///
/// 架构（2026-09-30 定稿）：三流量会在同一条通知流上任意交错
/// （设备录音时 App 查询列表、控制帧夹在音频包之间），因此不存在
/// 「实时模式/列表模式」的互斥状态机——[XyrixStreamRouter] 对整条流做
/// 统一标记扫描，按流中最早出现的标记分发：
/// - 扫到 0x54 → 按长度驱动解析一个音频包（跳过包内字节，假标记伤不到）
/// - 扫到 0x05 → 进入列表明文收集，直到 0x2F；若明文里先出现 0x54
///   标记，说明这个 0x05 是音频载荷里的假起始，立即中止收集
/// - 标记之间的字节：未出现过音频流量时按控制帧解码；录音期间跳过
///   （音频载荷里随机字节会被误判成命令码）
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dting/core/hardware/models.dart';
import 'package:dting/core/hardware/xyrix/xyrix_commands.dart';
import 'package:dting/core/hardware/xyrix/xyrix_frame_codec.dart';
import 'package:flutter/foundation.dart';

/// 文件列表收集器：0x05 标记之后、0x2F 结束帧之前是明文行。
class XyrixFileListCollector {
  bool _collecting = false;
  final BytesBuilder _raw = BytesBuilder(copy: true);

  /// 跨通知的尾部拼接缓冲：结束帧可能被 BLE 通知边界切开
  Uint8List _pending = Uint8List(0);

  bool get collecting => _collecting;

  void start() {
    _collecting = true;
    _raw.clear();
    _pending = Uint8List(0);
  }

  void reset() {
    _collecting = false;
    _raw.clear();
    _pending = Uint8List(0);
  }

  /// 喂入一段字节，返回 (解析出的文件列表或 null, 结束帧及其后字节)。
  /// [chunk] 从 0x05 标记之后开始。
  (List<RecordingFile>?, Uint8List) feed(Uint8List chunk) {
    if (!_collecting) {
      return (null, chunk);
    }
    final merged = _pending.isEmpty
        ? chunk
        : Uint8List.fromList([..._pending, ...chunk]);
    _pending = Uint8List(0);
    var endIdx = -1;
    for (var i = 0; i <= merged.length - 5; i++) {
      if (merged[i] == 0xFF &&
          merged[i + 1] == 0x55 &&
          merged[i + 2] == 0xAA &&
          merged[i + 3] == 0x00 &&
          merged[i + 4] == XyrixCommands.commandAck) {
        endIdx = i;
        break;
      }
    }
    if (endIdx < 0) {
      final keep = merged.length >= 4 ? 4 : merged.length;
      _raw.add(Uint8List.sublistView(merged, 0, merged.length - keep));
      _pending = Uint8List.fromList(
          Uint8List.sublistView(merged, merged.length - keep));
      if (_raw.length > 512 * 1024) {
        return (_parse(), Uint8List(0));
      }
      return (null, Uint8List(0));
    }
    if (endIdx > 0) {
      _raw.add(Uint8List.sublistView(merged, 0, endIdx));
    }
    final files = _parse();
    final tail = Uint8List.fromList(Uint8List.sublistView(merged, endIdx));
    return (files, tail);
  }

  List<RecordingFile> _parse() {
    _collecting = false;
    final text = utf8.decode(_raw.takeBytes(), allowMalformed: true);
    final files = <RecordingFile>[];
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) continue;
      final parsed = XyrixFrameCodec.parseFileListLine(line);
      if (parsed == null) {
        debugPrint('[Xyrix] 文件列表出现无法解析的行: ${line.trim()}');
        continue;
      }
      final path = parsed.path;
      final name = path.startsWith('0:/') ? path.substring(3) : path;
      files.add(RecordingFile(
        sn: files.length,
        name: name,
        sizeBytes: parsed.sizeBytes,
        startTime: _parseFileNameTime(name),
      ));
    }
    return files;
  }

  static DateTime? _parseFileNameTime(String name) {
    final m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-(\d{2})',
    ).firstMatch(name);
    if (m == null) return null;
    return DateTime.tryParse(
        '${m[1]}-${m[2]}-${m[3]} ${m[4]}:${m[5]}:${m[6]}');
  }
}

/// 实时音频流数据包
class XyrixOpusPacket {
  final int seq;

  /// 载荷原样字节（含子记录头，待厂商确认后精化）
  final Uint8List payload;

  const XyrixOpusPacket({required this.seq, required this.payload});
}

/// 统一流路由器：单状态 + 标记扫描，三流量任意交错。
class XyrixStreamRouter {
  final void Function(XyrixFrame frame) onFrame;
  final void Function(List<RecordingFile> files) onFileList;
  final void Function(XyrixOpusPacket packet) onOpusPacket;

  final XyrixFileListCollector _list = XyrixFileListCollector();

  /// 跨通知残余（半个标记/半个包/控制帧尾部）
  Uint8List _rx = Uint8List(0);

  /// 是否出现过实时音频流量（出现过之后标记间字节不再按控制帧解码，
  /// 避免音频载荷随机字节误触发命令）
  bool _sawOpusTraffic = false;

  XyrixStreamRouter({
    required this.onFrame,
    required this.onFileList,
    required this.onOpusPacket,
  });

  bool get collectingFileList => _list.collecting;
  bool get sawOpusTraffic => _sawOpusTraffic;

  void reset() {
    _list.reset();
    _rx = Uint8List(0);
    _sawOpusTraffic = false;
  }

  /// 喂入一条 BLE 通知
  void feed(List<int> value) {
    final merged = Uint8List.fromList([..._rx, ...value]);
    _rx = Uint8List(0);
    _scan(merged, 0);
  }

  /// 从 [pos] 起扫描 [chunk]，处理 marker/明文/包，尾部留存 _rx
  void _scan(Uint8List chunk, int pos) {
    if (_list.collecting) {
      // 明文里出现 0x54 标记 = 0x05 是音频载荷里的假起始，中止收集
      final fake = _findMarker(chunk, XyrixCommands.opusData, pos);
      if (fake >= 0) {
        debugPrint('[Xyrix] 列表收集中出现音频标记，判定假起始并中止');
        _list.reset();
        _scan(chunk, fake);
        return;
      }
      final rest = Uint8List.fromList(Uint8List.sublistView(chunk, pos));
      final (files, tail) = _list.feed(rest);
      if (files != null) onFileList(files);
      _afterTail(tail, listJustEnded: files != null);
      return;
    }
    final m05 = _findMarker(chunk, XyrixCommands.fileList, pos);
    final m54 = _findMarker(chunk, XyrixCommands.opusData, pos);
    if (m54 >= 0 && (m05 < 0 || m54 < m05)) {
      // 音频包：标记之前的字节交帧解码（连接初期的控制帧在这里）
      if (!_sawOpusTraffic) {
        _decodeFrames(Uint8List.sublistView(chunk, pos, m54));
      }
      final parsed = _parseOpusPacketAt(chunk, m54);
      if (parsed == null) {
        // 包不完整（跨通知）：从标记起留存
        _rx = Uint8List.fromList(Uint8List.sublistView(chunk, m54));
        return;
      }
      _sawOpusTraffic = true;
      onOpusPacket(parsed.$1);
      _scan(chunk, parsed.$2);
      return;
    }
    if (m05 >= 0) {
      if (!_sawOpusTraffic) {
        _decodeFrames(Uint8List.sublistView(chunk, pos, m05));
      }
      _list.start();
      _scan(chunk, m05 + 5);
      return;
    }
    // 无标记：收尾
    final rest = Uint8List.fromList(Uint8List.sublistView(chunk, pos));
    if (_list.collecting) {
      final (files, tail) = _list.feed(rest);
      if (files != null) onFileList(files);
      _afterTail(tail, listJustEnded: files != null);
      return;
    }
    if (!_sawOpusTraffic) {
      _decodeFrames(rest);
    } else {
      // 流中残余：保留可能成形的标记/包头，最多留 259 字节（最大包长）
      final keep = rest.length > 259 ? 259 : rest.length;
      _rx = Uint8List.fromList(
          Uint8List.sublistView(rest, rest.length - keep));
    }
  }

  /// 列表结束帧之后的残余：交回扫描（可能紧跟下一个标记）
  void _afterTail(Uint8List tail, {required bool listJustEnded}) {
    final (frames, rest) = XyrixFrameCodec.decode(tail);
    for (final frame in frames) {
      if (frame.command == XyrixCommands.fileList ||
          frame.command == XyrixCommands.opusData) {
        continue;
      }
      onFrame(frame);
    }
    // rest 交还扫描：可能包含 0x54 标记/半个标记
    if (rest.isEmpty) return;
    final m54 = _findMarker(rest, XyrixCommands.opusData, 0);
    final m05 = _findMarker(rest, XyrixCommands.fileList, 0);
    if (m54 >= 0 || m05 >= 0) {
      final markerPos = m54 >= 0 && (m05 < 0 || m54 < m05) ? m54 : m05;
      _rx = Uint8List(0);
      _scan(rest, markerPos);
    } else {
      _rx = rest;
    }
  }

  /// 在 [chunk][marker] 处解析一个音频数据包。
  /// 返回 (包, 下一位置)；数据不完整返回 null（调用方应留存等待）。
  (XyrixOpusPacket, int)? _parseOpusPacketAt(Uint8List chunk, int marker) {
    final p = marker + 5;
    if (chunk.length - p < 2) return null;
    final payloadLen = (chunk[p] << 8) | chunk[p + 1];
    // 数据包总长 = 2(长度) + 4(序列号) + N(载荷) + 2(CRC)
    final total = payloadLen + 8;
    if (chunk.length - p < total) return null;
    final packet = XyrixOpusPacket(
      seq: (chunk[p + 2] << 24) |
          (chunk[p + 3] << 16) |
          (chunk[p + 4] << 8) |
          chunk[p + 5],
      payload: Uint8List.fromList(
          Uint8List.sublistView(chunk, p + 6, p + 6 + payloadLen)),
    );
    return (packet, p + total);
  }

  static int _findMarker(Uint8List chunk, int command, int from) {
    for (var i = from; i <= chunk.length - 5; i++) {
      if (chunk[i] == 0xFF &&
          chunk[i + 1] == 0x55 &&
          chunk[i + 2] == 0xAA &&
          chunk[i + 3] == 0x00 &&
          chunk[i + 4] == command) {
        return i;
      }
    }
    return -1;
  }

  void _decodeFrames(Uint8List chunk) {
    if (chunk.isEmpty) return;
    final (frames, rest) = XyrixFrameCodec.decode(chunk);
    for (final frame in frames) {
      if (frame.command == XyrixCommands.fileList ||
          frame.command == XyrixCommands.opusData) {
        continue;
      }
      onFrame(frame);
    }
    _rx = rest;
  }
}

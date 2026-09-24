/// Xyrix 通知流解析（无 BLE 依赖，可用真机抓包字节单元重放）。
///
/// 设计要点（2026-09-24 联调实证）：
/// - 设备响应混合存在：普通命令帧（`FF 55 AA [len][cmd][data]`）、
///   文件列表（`FF 55 AA 00 05` + 明文行 + `FF 55 AA 00 2F`）、
///   实时音频流（`FF 55 AA 00 54` 标记帧 + 自描述数据包
///   `[2B 长度 BE][4B 序列号 BE][载荷 N][2B CRC]`，载荷内含子记录头，待厂商确认）。
/// - 0x05 起始帧与结束 ACK 可能落在同一条 BLE 通知里：若先走帧解码，
///   ACK 会被当帧消费掉，收集器永远等不到结束帧 → 列表静默丢失。
///   因此 [XyrixNotificationRouter] 对列表/实时流一律按**原始标记扫描**路由，
///   帧解码只负责标记之外的控制帧。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dting/hardware/models.dart';
import 'package:dting/hardware/xyrix/xyrix_commands.dart';
import 'package:dting/hardware/xyrix/xyrix_frame_codec.dart';
import 'package:flutter/foundation.dart';

/// 文件列表收集器：`FF 55 AA 00 05` 之后、`FF 55 AA 00 2F` 之前是明文行。
class XyrixFileListCollector {
  bool _collecting = false;
  final BytesBuilder _raw = BytesBuilder(copy: true);

  /// 跨通知的尾部拼接缓冲：结束帧 `FF 55 AA 00 2F` 可能被 BLE 通知边界
  /// 切开（如 `FF 55 AA` 结尾一条、`00 2F` 开头下一条）。没有它，
  /// 恰好跨界的结束帧永远匹配不上，收集卡死、后续列表全部被吞
  /// （2026-09-24 真机「列表回包正常但 app 不显示」的根因）。
  Uint8List _pending = Uint8List(0);

  bool get collecting => _collecting;

  /// 收到 0x05 起始标记：进入收集模式
  void start() {
    _collecting = true;
    _raw.clear();
    _pending = Uint8List(0);
  }

  /// 丢弃进行中的收集（断连/超时）
  void reset() {
    _collecting = false;
    _raw.clear();
    _pending = Uint8List(0);
  }

  /// 喂入一段字节（须含历史残余），返回 (解析出的文件列表或 null, 结束帧及其后字节)。
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
      // 末尾最多 4 字节可能是被切开的结束帧开头，留待下一段拼接
      final keep = merged.length >= 4 ? 4 : merged.length;
      _raw.add(Uint8List.sublistView(merged, 0, merged.length - keep));
      _pending =
          Uint8List.fromList(Uint8List.sublistView(merged, merged.length - keep));
      // 兜底：结束帧丢失时防止无限累积
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

  /// 文件名形如 `2026-09-21-09-57-34.wav`，内嵌录音开始时间
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
  /// 设备侧序列号（丢包检测用）
  final int seq;

  /// 载荷原样字节（含子记录头，待厂商确认后精化）
  final Uint8List payload;

  const XyrixOpusPacket({required this.seq, required this.payload});
}

/// 实时音频流解析器：标记帧 `FF 55 AA 00 54` 后跟自描述数据包。
class XyrixRealtimeParser {
  static final Uint8List _marker =
      Uint8List.fromList([0xFF, 0x55, 0xAA, 0x00, XyrixCommands.opusData]);

  /// 喂入一段字节，返回 (解析出的数据包列表, 未消费残余字节)。
  /// 残余包含不完整的数据包尾部（下轮凑齐）与夹在流中的其它字节。
  (List<XyrixOpusPacket>, Uint8List) feed(Uint8List chunk) {
    final packets = <XyrixOpusPacket>[];
    var i = 0;
    while (true) {
      final markerIdx = _find(chunk, _marker, i);
      if (markerIdx < 0) break;
      final p = markerIdx + _marker.length;
      if (chunk.length - p < 2) break;
      final payloadLen = (chunk[p] << 8) | chunk[p + 1];
      // 数据包总长 = 2(长度) + 4(序列号) + N(载荷) + 2(CRC)
      final total = payloadLen + 8;
      if (chunk.length - p < total) break;
      packets.add(XyrixOpusPacket(
        seq: chunk[p + 5] |
            (chunk[p + 4] << 8) |
            (chunk[p + 3] << 16) |
            (chunk[p + 2] << 24),
        payload: Uint8List.sublistView(chunk, p + 6, p + 6 + payloadLen),
      ));
      i = p + total;
    }
    final rest = i >= chunk.length
        ? Uint8List(0)
        : Uint8List.fromList(Uint8List.sublistView(chunk, i));
    return (packets, rest);
  }

  static int _find(Uint8List data, Uint8List pattern, int from) {
    for (var i = from; i <= data.length - pattern.length; i++) {
      var match = true;
      for (var j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }
}

/// 通知流路由器：统一处理命令帧 / 文件列表 / 实时音频流三种载荷，
/// 内部维护跨通知的残余缓冲。适配器只需把每条 BLE 通知喂给 [feed]。
class XyrixNotificationRouter {
  final void Function(XyrixFrame frame) onFrame;
  final void Function(List<RecordingFile> files) onFileList;
  final void Function(XyrixOpusPacket packet) onOpusPacket;

  final XyrixFileListCollector _list = XyrixFileListCollector();
  final XyrixRealtimeParser _rt = XyrixRealtimeParser();
  bool _rtActive = false;
  Uint8List _rx = Uint8List(0);

  XyrixNotificationRouter({
    required this.onFrame,
    required this.onFileList,
    required this.onOpusPacket,
  });

  bool get collectingFileList => _list.collecting;
  bool get receivingRealtime => _rtActive;

  /// 实时流结束（断连/录音停止后调用）：退出流模式
  void resetRealtime() {
    _rtActive = false;
  }

  void reset() {
    _list.reset();
    _rtActive = false;
    _rx = Uint8List(0);
  }

  /// 喂入一条 BLE 通知
  void feed(List<int> value) {
    final merged = Uint8List.fromList([..._rx, ...value]);
    _rx = Uint8List(0);
    _route(merged);
  }

  void _route(Uint8List chunk) {
    if (chunk.isEmpty) return;
    if (_list.collecting) {
      final (files, tail) = _list.feed(chunk);
      if (files != null) onFileList(files);
      _route(tail);
      return;
    }
    if (_rtActive) {
      _feedRt(chunk);
      return;
    }
    // 列表/实时流标记按原始字节扫描路由：帧解码器绝不越过标记去扫描
    // 数据包字节——音频载荷里可能出现 `FF 55 AA` 序列，被误当帧头后会
    // 吞掉整个数据包（真机抓包 5/8B 分包重放实证）
    final listIdx = _findMarker(chunk, XyrixCommands.fileList);
    final rtIdx = _findMarker(chunk, XyrixCommands.opusData);
    if (rtIdx >= 0 && (listIdx < 0 || rtIdx < listIdx)) {
      _dispatchFrames(Uint8List.sublistView(chunk, 0, rtIdx));
      _rtActive = true;
      // 实时解析器以标记帧定位数据包，必须连标记一起喂；
      // （列表相反：收集器只吃标记之后的明文，见下）
      _feedRt(Uint8List.sublistView(chunk, rtIdx));
      return;
    }
    if (listIdx >= 0) {
      _dispatchFrames(Uint8List.sublistView(chunk, 0, listIdx));
      _list.start();
      final (files, tail) = _list.feed(Uint8List.sublistView(chunk, listIdx + 5));
      if (files != null) onFileList(files);
      _route(tail);
      return;
    }
    _dispatchFrames(chunk);
  }

  static int _findMarker(Uint8List chunk, int command) {
    for (var i = 0; i <= chunk.length - 5; i++) {
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

  void _feedRt(Uint8List chunk) {
    if (chunk.isEmpty) return;
    final (packets, rest) = _rt.feed(chunk);
    for (final p in packets) {
      onOpusPacket(p);
    }
    _rx = rest;
  }

  void _dispatchFrames(Uint8List chunk) {
    if (chunk.isEmpty) return;
    final (frames, rest) = XyrixFrameCodec.decode(chunk);
    for (final frame in frames) {
      if (frame.command == XyrixCommands.opusData ||
          frame.command == XyrixCommands.fileList) {
        // 两类标记帧已由原始字节扫描路径处理，正常不会走到这里
        continue;
      }
      onFrame(frame);
    }
    _rx = rest.length > 4096 ? Uint8List(0) : rest;
  }
}

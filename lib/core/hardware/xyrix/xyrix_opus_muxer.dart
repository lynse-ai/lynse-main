import 'dart:convert';
import 'dart:typed_data';

/// Xyrix 音频 → 可播放 Ogg Opus 的唯一一份实现（Dart 侧）。
///
/// 容器规则（真机逐字节实证）：`[8B 小端长度 L][0x48][L-1 B]`，
/// 其中 **`0x48` 是 Opus 的 TOC**（config 9 = SILK WB 20 ms、code 0、单声道），
/// 长度字段把 TOC 算进去，所以**完整 Opus 包 = `0x48` + 那 L-1 字节**。
///
/// 分页规则必须与 Kotlin `LynseOggOpusWriter` / Swift / Node 参考实现逐字节一致：
/// lacing 攒到 250 才 flush、页边界只落在包边界。改了任何一边都要重出对拍向量。
class XyrixOpusMuxer {
  static const int _pageLacingLimit = 250;
  static const int _serial = 0x58595249;

  final void Function(Uint8List page) onPage;
  final int channels;
  final int preSkip;
  final int inputSampleRateHz;
  final int samplesPerPacket;

  XyrixOpusMuxer({
    required this.onPage,
    this.channels = 1,
    this.preSkip = 312,
    this.inputSampleRateHz = 48000,
    this.samplesPerPacket = 960,
  });

  final BytesBuilder _body = BytesBuilder(copy: false);
  final BytesBuilder _lacing = BytesBuilder(copy: false);
  int _granule = 0;
  int _sequence = 0;
  int _pendingPackets = 0;
  bool _started = false;
  bool _finished = false;

  void start() {
    if (_started) throw StateError('Ogg Opus 头页已经写过');
    _started = true;
    final head = BytesBuilder()
      ..add(utf8.encode('OpusHead'))
      ..addByte(1)
      ..addByte(channels)
      ..add(_u16(preSkip))
      ..add(_u32(inputSampleRateHz))
      ..add(_u16(0))
      ..addByte(0);
    final headBytes = head.toBytes();
    _emit(headBytes, _lacingFor(headBytes.length), 0x02, 0);
    final tags = BytesBuilder()
      ..add(utf8.encode('OpusTags'))
      ..add(_u32(0))
      ..add(_u32(0));
    final tagBytes = tags.toBytes();
    _emit(tagBytes, _lacingFor(tagBytes.length), 0x00, 0);
  }

  void writePacket(List<int> packet) {
    if (!_started || _finished) throw StateError('XyrixOpusMuxer 状态不对');
    _body.add(packet);
    _lacing.add(_lacingFor(packet.length));
    _granule += samplesPerPacket;
    _pendingPackets++;
    if (_lacing.length >= _pageLacingLimit) _flush(false);
  }

  void finish() {
    if (_finished) return;
    _finished = true;
    if (_pendingPackets == 0) {
      // 上一包刚好填满一页：不补一页整条流就没有 EOS 页。空页（0 段）合法。
      _emit(Uint8List(0), Uint8List(0), 0x04, _granule);
      return;
    }
    _flush(true);
  }

  /// 从原样落盘的 0x54 存档里切出完整 Opus 包（含 TOC）。
  /// 遇到不像块头的字节**向前重同步**，但把跳过的字节数如实记进 [skippedBytes]：
  /// 静默跳会把「传输丢包」伪装成「载荷解不开」，这两个结论完全不一样。
  static int skippedBytes = 0;

  static List<Uint8List> unpackChunks(Uint8List stream) {
    final out = <Uint8List>[];
    skippedBytes = 0;
    var p = 0;
    while (p + 9 <= stream.length) {
      final length = ByteData.sublistView(stream, p, p + 8).getUint64(0, Endian.little);
      final plausible = length >= 2 &&
          length <= (1 << 20) &&
          stream[p + 8] == 0x48 &&
          p + 8 + length <= stream.length &&
          _sevenZeros(stream, p + 1);
      if (!plausible) {
        p += 1;
        skippedBytes += 1;
        continue;
      }
      out.add(Uint8List.sublistView(stream, p + 8, p + 8 + length));
      p += 8 + length;
    }
    return out;
  }

  static bool _sevenZeros(Uint8List s, int at) {
    for (var i = 0; i < 7; i++) {
      if (s[at + i] != 0) return false;
    }
    return true;
  }

  void _flush(bool finalPage) {
    if (_pendingPackets == 0) return;
    _emit(_body.toBytes(), _lacing.toBytes(), finalPage ? 0x04 : 0x00, _granule);
    _body.clear();
    _lacing.clear();
    _pendingPackets = 0;
  }

  void _emit(Uint8List body, Uint8List lacing, int headerType, int granulePos) {
    final page = Uint8List(27 + lacing.length + body.length);
    final view = ByteData.sublistView(page);
    page.setRange(0, 4, utf8.encode('OggS'));
    page[4] = 0;
    page[5] = headerType;
    view.setUint64(6, granulePos, Endian.little);
    view.setUint32(14, _serial, Endian.little);
    view.setUint32(18, _sequence++, Endian.little);
    view.setUint32(22, 0, Endian.little);
    page[26] = lacing.length;
    page.setRange(27, 27 + lacing.length, lacing);
    page.setRange(27 + lacing.length, page.length, body);
    final crc = _crc32(page);
    view.setUint32(22, crc, Endian.little);
    onPage(page);
  }

  static Uint8List _lacingFor(int len) {
    final out = Uint8List(len ~/ 255 + 1);
    for (var i = 0; i < len ~/ 255; i++) {
      out[i] = 255;
    }
    out[out.length - 1] = len % 255;
    return out;
  }

  static Uint8List _u16(int v) => Uint8List(2)
    ..[0] = v & 0xFF
    ..[1] = (v >> 8) & 0xFF;

  static Uint8List _u32(int v) => Uint8List(4)
    ..[0] = v & 0xFF
    ..[1] = (v >> 8) & 0xFF
    ..[2] = (v >> 16) & 0xFF
    ..[3] = (v >> 24) & 0xFF;

  static final List<int> _crcTable = List<int>.generate(256, (n) {
    var c = n << 24;
    for (var k = 0; k < 8; k++) {
      c = (c & 0x80000000) != 0 ? ((c << 1) ^ 0x04C11DB7) & 0xFFFFFFFF : (c << 1) & 0xFFFFFFFF;
    }
    return c;
  });

  /// Ogg 用 MSB-first 0x04C11DB7、初值 0、无末位取反 —— 和 zip/png 那套不一样。
  static int _crc32(Uint8List bytes) {
    var c = 0;
    for (final b in bytes) {
      c = ((c << 8) & 0xFFFFFFFF) ^ _crcTable[((c >> 24) & 0xFF) ^ b];
    }
    return c & 0xFFFFFFFF;
  }
}

/// 增量版切块器：GATT 通知不保证对齐块边界，所以必须能半块挂着等下一次。
/// 与 [XyrixOpusMuxer.unpackChunks] 同一套规则（含 `0x48` TOC、向前重同步并计数）。
class XyrixChunkAccumulator {
  final BytesBuilder _pending = BytesBuilder(copy: true);
  int skippedBytes = 0;
  int packetsEmitted = 0;

  static const int _lengthBytes = 8;
  static const int _maxBlock = 1 << 20;

  List<Uint8List> addData(Uint8List chunk) {
    _pending.add(chunk);
    final buf = _pending.toBytes();
    final out = <Uint8List>[];
    var p = 0;
    while (true) {
      if (buf.length - p < _lengthBytes + 1) break;
      final length = ByteData.sublistView(buf, p, p + _lengthBytes).getUint64(0, Endian.little);
      final plausible = length >= 2 &&
          length <= _maxBlock &&
          buf[p + _lengthBytes] == 0x48 &&
          _sevenZeros(buf, p + 1);
      if (!plausible) {
        p += 1;
        skippedBytes += 1;
        continue;
      }
      if (buf.length - p < _lengthBytes + length) break; // 半块，等下一次
      out.add(Uint8List.sublistView(buf, p + _lengthBytes, p + _lengthBytes + length));
      p += _lengthBytes + length;
    }
    final rest = BytesBuilder(copy: false);
    rest.add(Uint8List.sublistView(buf, p));
    _pending.clear();
    _pending.add(rest.toBytes());
    packetsEmitted += out.length;
    return out;
  }

  static bool _sevenZeros(Uint8List s, int at) {
    for (var i = 0; i < 7; i++) {
      if (s[at + i] != 0) return false;
    }
    return true;
  }
}

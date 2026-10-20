import 'dart:io';
import 'dart:typed_data';
import 'package:dting/core/hardware/xyrix/xyrix_opus_muxer.dart';

/// 跨语言对拍：Dart 打包器必须和 Node 参考实现输出逐字节相同的 Ogg 流。
void main(List<String> args) {
  final stream = File(args[0]).readAsBytesSync();
  final packets = XyrixOpusMuxer.unpackChunks(stream);
  final out = BytesBuilder(copy: false);
  final muxer = XyrixOpusMuxer(onPage: (p) => out.add(p));
  muxer.start();
  for (final packet in packets) {
    muxer.writePacket(packet);
  }
  muxer.finish();
  final bytes = out.toBytes();
  File(args[1]).writeAsBytesSync(bytes);
  stdout.writeln('packets=${packets.length} bytes=${bytes.length} skipped=${XyrixOpusMuxer.skippedBytes}');
}

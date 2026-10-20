/// 传输落盘目标：进行中只写 `.part`，字节数校验通过后才原子改名为正式文件。
///
/// 存在的意义是把「链路结束」和「内容完好」分成两件事：断点文件天然就是
/// 续传偏移量（`File.length()`），不存在可能与真实字节数脱节的第二份进度记录；
/// 而未通过 [finalize] 的字节永远不会被上层当成一条录音。
library;

import 'dart:io';

import 'package:dting/core/hardware/models.dart';

class TransferTarget {
  /// 传输期间写入的文件，字节数即当前断点
  final File partFile;

  /// 校验通过后落地的正式文件
  final File finalFile;

  const TransferTarget({required this.partFile, required this.finalFile});

  static TransferTarget inDirectory(Directory dir, String fileName,
          {required String prefix}) =>
      TransferTarget(
        partFile: File('${dir.path}/$prefix$fileName.part'),
        finalFile: File('${dir.path}/$prefix$fileName'),
      );

  /// 已有断点的字节数；无断点返回 0。
  Future<int> resumeOffset() async {
    try {
      if (!await partFile.exists()) return 0;
      return await partFile.length();
    } catch (_) {
      return 0;
    }
  }

  Future<void> discard() async {
    try {
      if (await partFile.exists()) await partFile.delete();
    } catch (_) {}
  }

  /// 关闭写入句柄并核对字节数：相符才把断点提升为正式文件。
  ///
  /// [expectedBytes] `<= 0` 表示期望大小未知（设备未确认、列表也没给），
  /// 此时不做校验判定，返回 [TransferIntegrity.unverified] 并保留断点。
  Future<TransferOutcome> finalize(IOSink sink, int expectedBytes) async {
    try {
      await sink.flush();
      await sink.close();
    } catch (_) {}

    final actual = await _partLength();
    if (expectedBytes <= 0) {
      return TransferOutcome(
        integrity: TransferIntegrity.unverified,
        expectedBytes: 0,
        actualBytes: actual,
        filePath: partFile.path,
      );
    }
    if (actual != expectedBytes) {
      return TransferOutcome(
        integrity: TransferIntegrity.sizeMismatch,
        expectedBytes: expectedBytes,
        actualBytes: actual,
        filePath: partFile.path,
      );
    }
    try {
      if (await finalFile.exists()) await finalFile.delete();
      final renamed = await partFile.rename(finalFile.path);
      return TransferOutcome(
        integrity: TransferIntegrity.verified,
        expectedBytes: expectedBytes,
        actualBytes: await renamed.length(),
        filePath: renamed.path,
      );
    } catch (e) {
      return TransferOutcome(
        integrity: TransferIntegrity.sizeMismatch,
        expectedBytes: expectedBytes,
        actualBytes: actual,
        filePath: partFile.path,
        error: '落盘失败: $e',
      );
    }
  }

  Future<int> _partLength() async {
    try {
      return await partFile.length();
    } catch (_) {
      return 0;
    }
  }
}

/// 一次传输的完整性结论
class TransferOutcome {
  final TransferIntegrity integrity;
  final int expectedBytes;
  final int actualBytes;
  final String filePath;
  final String? error;

  const TransferOutcome({
    required this.integrity,
    required this.expectedBytes,
    required this.actualBytes,
    required this.filePath,
    this.error,
  });

  bool get trusted => integrity == TransferIntegrity.verified;

  @override
  String toString() =>
      'TransferOutcome($integrity $actualBytes/$expectedBytes → $filePath)';
}

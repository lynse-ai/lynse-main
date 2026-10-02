/// 录音索引仓库：sqlite recordings 表 + 本地音频目录扫描入库。
///
/// 取代旧「每次进页扫描目录」的方式：扫描结果写入 sqlite 索引，
/// 列表/统计/云状态都挂在这张表上。
library;

import 'dart:io';

import 'package:dting/utils/local_sqldb.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// 一条本地录音（recordings 表的行）。
class RecordingEntry {
  final int? id;
  final String filePath;
  final String fileName;
  final int fileSize;
  final int? durationMs;

  /// device_ble | device_wifi | realtime | local
  final String source;
  final String transStatus;
  final String? cloudFileId;
  final DateTime createdAt;

  const RecordingEntry({
    this.id,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.durationMs,
    required this.source,
    this.transStatus = 'none',
    this.cloudFileId,
    required this.createdAt,
  });

  Map<String, Object?> toRow() => {
        'filePath': filePath,
        'fileName': fileName,
        'ext': fileName.contains('.') ? fileName.split('.').last : null,
        'fileSize': fileSize,
        'durationMs': durationMs,
        'source': source,
        'transStatus': transStatus,
        'cloudFileId': cloudFileId,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

  static RecordingEntry fromRow(Map<String, Object?> r) => RecordingEntry(
        id: r['id'] as int?,
        filePath: r['filePath'] as String,
        fileName: r['fileName'] as String,
        fileSize: (r['fileSize'] as num?)?.toInt() ?? 0,
        durationMs: (r['durationMs'] as num?)?.toInt(),
        source: (r['source'] as String?) ?? 'local',
        transStatus: (r['transStatus'] as String?) ?? 'none',
        cloudFileId: r['cloudFileId'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (r['createdAt'] as num?)?.toInt() ?? 0,
        ),
      );

  String get sizeLabel =>
      fileSize >= 1024 * 1024
          ? '${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB'
          : '${(fileSize / 1024).toStringAsFixed(0)} KB';

  String get sourceLabel => switch (source) {
        'device_ble' => '蓝牙下载',
        'device_wifi' => 'WiFi 快传',
        'realtime' => '实时录音',
        _ => '本地导入',
      };
}

class RecordingRepository {
  Database? get _db => SqlDBHelper.database;

  static const _audioExts = ['.mp3', '.wav', '.m4a', '.opus'];

  /// 扫描应用音频目录并把结果同步进索引表，返回按时间倒序的全量列表。
  ///
  /// filePath 为唯一键：已入库的文件只更新大小/时间，不重复插入；
  /// 磁盘上已消失的行不主动删（保留云转写关联），列表层过滤存在性。
  Future<List<RecordingEntry>> scanAndSync() async {
    final db = _db;
    if (db == null) return [];

    final files = <File>[];
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dirs = <Directory>[docs];
      try {
        dirs.add(Directory('${docs.parent.path}/Caches'));
      } catch (_) {}
      try {
        dirs.add(await getTemporaryDirectory());
      } catch (_) {}
      for (final dir in dirs) {
        if (!await dir.exists()) continue;
        await for (final e in dir.list(recursive: true, followLinks: false)) {
          if (e is! File) continue;
          final lower = e.path.toLowerCase();
          if (_audioExts.any(lower.endsWith)) files.add(e);
        }
      }
    } catch (e) {
      debugPrint('[RecordingRepository] 扫描失败: $e');
    }

    for (final f in files) {
      final stat = f.statSync();
      final name = f.path.split('/').last;
      await db.insert(
        'recordings',
        RecordingEntry(
          filePath: f.path,
          fileName: name,
          fileSize: stat.size,
          source: _sourceOf(name),
          createdAt: stat.modified,
        ).toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    return listAll();
  }

  /// 全量列表（新→旧，只保留磁盘上仍存在的文件）。
  Future<List<RecordingEntry>> listAll() async {
    final db = _db;
    if (db == null) return const [];
    final rows = await db.query('recordings', orderBy: 'createdAt DESC');
    final entries = rows.map(RecordingEntry.fromRow).toList();
    return entries.where((e) => File(e.filePath).existsSync()).toList();
  }

  /// 今日新增数量（Today 统计用）。
  Future<int> todayCount() async {
    final all = await listAll();
    final today = DateTime.now();
    return all
        .where((e) =>
            e.createdAt.year == today.year &&
            e.createdAt.month == today.month &&
            e.createdAt.day == today.day)
        .length;
  }

  Future<void> updateTransStatus(int id, {required String status, String? cloudFileId}) async {
    final db = _db;
    if (db == null) return;
    await db.update(
      'recordings',
      {
        'transStatus': status,
        if (cloudFileId != null) 'cloudFileId': cloudFileId,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 按文件名推断来源（硬件层落盘前缀约定）。
  String _sourceOf(String fileName) {
    if (fileName.startsWith('xyrix_dl_')) return 'device_ble';
    if (fileName.startsWith('xyrix_wifi_')) return 'device_wifi';
    if (fileName.startsWith('xyrix_rt_')) return 'realtime';
    return 'local';
  }
}

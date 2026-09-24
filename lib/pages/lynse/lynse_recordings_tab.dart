/// 记录 tab：本地录音文件列表（扫描应用音频目录）。
library;

import 'dart:io';

import 'package:dting/pages/lynse/lynse_widgets.dart';
import 'package:dting/styles/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

class LynseRecordingsTab extends StatefulWidget {
  const LynseRecordingsTab({super.key});

  @override
  State<LynseRecordingsTab> createState() => _LynseRecordingsTabState();
}

class _LynseRecordingsTabState extends State<LynseRecordingsTab> {
  final _files = <FileSystemEntity>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _loading = true);
    final result = <FileSystemEntity>{};
    try {
      final dirs = <Directory>[];
      final docs = await getApplicationDocumentsDirectory();
      dirs.add(docs);
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
          final ext = e.path.toLowerCase();
          if (ext.endsWith('.mp3') ||
              ext.endsWith('.wav') ||
              ext.endsWith('.m4a') ||
              ext.endsWith('.opus')) {
            result.add(e);
          }
        }
      }
    } catch (_) {}
    final list = result.toList()
      ..sort((a, b) => (b.statSync().modified).compareTo(a.statSync().modified));
    if (mounted) {
      setState(() {
        _files
          ..clear()
          ..addAll(list);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.lynse;
    return RefreshIndicator(
      color: s.brand,
      onRefresh: _scan,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    LynseEmpty(
                      icon: Icons.graphic_eq_outlined,
                      title: '还没有录音记录',
                      subtitle: '连接设备录音后，文件会出现在这里',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _files.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final f = _files[i];
                    final stat = f.statSync();
                    final name = f.path.split('/').last;
                    return LynseCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      onTap: () => Get.toNamed(
                        '/lynseRecordingDetail',
                        arguments: {'localPath': f.path, 'title': name},
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: s.brand.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.graphic_eq,
                                size: 18, color: s.brand),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: s.foreground,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${stat.modified.month}月${stat.modified.day}日 · '
                                  '${(stat.size / 1024 / 1024).toStringAsFixed(1)} MB',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: s.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 18, color: s.mutedForeground),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

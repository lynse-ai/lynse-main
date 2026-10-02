/// 录音库屏：sqlite 索引驱动的录音列表（Phase 3 正式版）。
library;

import 'package:dting/core/data/recording_repository.dart';
import 'package:dting/core/services/playback_service.dart';
import 'package:dting/core/services/recording_library.dart';
import 'package:dting/router/modules/assistant_router.dart';
import 'package:dting/ui/components.dart';
import 'package:dting/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RecordingsPage extends StatelessWidget {
  const RecordingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = RecordingLibrary.instance;
    final playback = PlaybackService.instance;
    return Obx(() {
      if (library.loading.value && library.recordings.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      final items = library.recordings;
      if (items.isEmpty) {
        return ListView(
          padding: const EdgeInsets.all(LSpacing.xl),
          children: const [
            SizedBox(height: 80),
            LCard(
              child: LEmpty(
                icon: Icons.graphic_eq,
                title: '还没有录音',
                message: '连接设备后下载的录音会出现在这里',
              ),
            ),
          ],
        );
      }
      return RefreshIndicator(
        onRefresh: library.refreshLibrary,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(LSpacing.xl, 4, LSpacing.xl, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final r = items[i];
            final active = playback.currentPath.value == r.filePath;
            final playing = active && playback.isPlaying.value;
            return _RecordingRow(
              entry: r,
              playing: playing,
              onTap: () => Get.toNamed(
                AssistantRouter.recordingDetail,
                arguments: {'localPath': r.filePath, 'title': r.fileName},
              ),
              onPlayTap: () => playback.play(r.filePath, title: r.fileName),
            );
          },
        ),
      );
    });
  }
}

class _RecordingRow extends StatelessWidget {
  const _RecordingRow({
    required this.entry,
    required this.playing,
    required this.onTap,
    required this.onPlayTap,
  });

  final RecordingEntry entry;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onPlayTap;

  @override
  Widget build(BuildContext context) {
    final d = entry.createdAt;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LRadius.card),
      child: LCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _PlayBadge(playing: playing, onTap: onPlayTap),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LType.body.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.month}月${d.day}日 · ${entry.sizeLabel} · ${entry.sourceLabel}',
                    style: LType.small,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: LColors.muted),
          ],
        ),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: playing ? LColors.blue : LColors.sky,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          playing ? Icons.pause : Icons.play_arrow,
          size: 20,
          color: LColors.blueDark,
        ),
      ),
    );
  }
}

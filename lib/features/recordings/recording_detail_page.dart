/// 录音详情页：播放条 + 转写 / 时间轴 / 纪要 三 tab + 编辑 + 导出。
///
/// 自 lib/pages/lynse/lynse_recording_detail_page.dart 迁移并接入
/// PlaybackService；样式切换为新设计系统。云端内容（转写/纪要）依赖
/// Lynse 后端联调，缺失时优雅降级为本地播放 + 空态。
library;

import 'package:dting/core/services/playback_service.dart';
import 'package:dting/http/lynse_api.dart';
import 'package:dting/ui/components.dart';
import 'package:dting/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 说话人色板（8 色，替代旧 LynseColors.speakers）
const _speakerColors = <Color>[
  Color(0xFF1473C8),
  Color(0xFF3A7D5C),
  Color(0xFF8A5FB0),
  Color(0xFFB0703C),
  Color(0xFF4C7A9E),
  Color(0xFF9E4C6E),
  Color(0xFF5C6E3A),
  Color(0xFF7A4C4C),
];

class RecordingDetailPage extends StatefulWidget {
  const RecordingDetailPage({super.key});

  @override
  State<RecordingDetailPage> createState() => _RecordingDetailPageState();
}

class _RecordingDetailPageState extends State<RecordingDetailPage> {
  String _title = '录音详情';
  String? _localPath;
  String? _fileId;

  bool _loading = false;
  String? _error;
  List<TransSegment> _segments = [];
  List<Conclusion> _conclusions = [];
  Outline? _outline;
  List<ActionTodo> _todos = [];

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      _title = args['title']?.toString() ?? _title;
      _localPath = args['localPath']?.toString();
      _fileId = args['fileId']?.toString();
    }
    _load();
  }

  Future<void> _load() async {
    if (_fileId == null || _fileId!.isEmpty) {
      setState(() => _error = null);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final segments = await LynseApi.fetchTranscription(_fileId!);
      final conclusions = await LynseApi.conclusions(_fileId!);
      final outline = await LynseApi.outline(_fileId!);
      final todos = await LynseApi.todos(_fileId!);
      if (mounted) {
        setState(() {
          _segments = segments;
          _conclusions = conclusions;
          _outline = outline;
          _todos = todos;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '云端内容加载失败：$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (_fileId != null)
              IconButton(
                icon: const Icon(Icons.ios_share, size: 20),
                tooltip: '导出',
                onPressed: _showExportSheet,
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '转写'),
              Tab(text: '时间轴'),
              Tab(text: '纪要'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_localPath != null) _PlayerBar(localPath: _localPath!, title: _title),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildTranscriptTab(showSpeaker: true),
                        _buildTranscriptTab(showSpeaker: false),
                        _buildSummaryTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 播放条
  // ------------------------------------------------------------------

  // ------------------------------------------------------------------
  // 转写 / 时间轴
  // ------------------------------------------------------------------

  Widget _buildTranscriptTab({required bool showSpeaker}) {
    if (_fileId == null || _fileId!.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(LSpacing.md),
        children: const [
          LCard(
            child: LEmpty(
              icon: Icons.cloud_upload_outlined,
              title: '本地录音尚未同步',
              message: '文件同步到云端并完成转写后，这里会显示可编辑的转写文本',
            ),
          ),
        ],
      );
    }
    if (_error != null && _segments.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(LSpacing.md),
        children: [
          LCard(
            child: Column(
              children: [
                LEmpty(icon: Icons.cloud_off_outlined, title: _error!),
                const SizedBox(height: 8),
                TextButton(onPressed: _load, child: const Text('重试')),
              ],
            ),
          ),
        ],
      );
    }
    if (_segments.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(LSpacing.md),
        children: const [
          LCard(child: LEmpty(icon: Icons.notes, title: '暂无转写内容')),
        ],
      );
    }
    String? lastSpeaker;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(LSpacing.md, 12, LSpacing.md, 24),
      itemCount: _segments.length,
      itemBuilder: (_, i) {
        final seg = _segments[i];
        final speakerChanged = showSpeaker && seg.speakerName != lastSpeaker;
        lastSpeaker = seg.speakerName;
        final speakerColor = _speakerColors[(int.tryParse(seg.speakerId ?? '0') ?? 0)
            .clamp(0, _speakerColors.length - 1)];
        return _SegmentTile(
          seg: seg,
          speakerChanged: speakerChanged,
          speakerColor: speakerColor,
          localLoaded: _localPath != null,
          onEdit: () => _editSegmentDialog(seg),
          onRenameSpeaker: () => _renameSpeakerDialog(seg),
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // 纪要 tab
  // ------------------------------------------------------------------

  Widget _buildSummaryTab() {
    if (_fileId == null || _fileId!.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(LSpacing.md),
        children: const [
          LCard(
            child: LEmpty(icon: Icons.auto_awesome_outlined, title: '同步并转写后可生成 AI 纪要'),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(LSpacing.md, 12, LSpacing.md, 24),
      children: [
        if (_outline != null) ...[
          const LSectionHeading(label: '大纲'),
          const SizedBox(height: 6),
          LCard(
            child: Text(
              _outline!.text,
              style: LType.muted.copyWith(height: 1.6, color: LColors.text),
            ),
          ),
          const SizedBox(height: LSpacing.md),
        ],
        const LSectionHeading(label: '总结'),
        const SizedBox(height: 6),
        if (_conclusions.isEmpty)
          const LCard(
            child: LEmpty(
              icon: Icons.auto_awesome_outlined,
              title: '暂无总结',
              message: '转写完成后选择模板生成',
            ),
          )
        else
          ..._conclusions.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.templateName.isEmpty ? '总结' : c.templateName,
                      style: LType.body.copyWith(fontWeight: FontWeight.w600, color: LColors.blueDark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.text,
                      style: LType.muted.copyWith(height: 1.6, color: LColors.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: LSpacing.md),
        const LSectionHeading(label: '行动项'),
        const SizedBox(height: 6),
        if (_todos.isEmpty)
          const LCard(child: LEmpty(icon: Icons.checklist, title: '暂无行动项'))
        else
          LCard(
            child: Column(
              children: _todos
                  .map((t) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: t.completed,
                        activeColor: LColors.blueDark,
                        title: Text(
                          t.content,
                          style: LType.muted.copyWith(color: LColors.text),
                        ),
                        onChanged: (v) {
                          // TODO(联调): 后端确认后接 updateTodo
                          Get.snackbar('提示', '行动项更新将在联调后启用');
                        },
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 编辑弹窗
  // ------------------------------------------------------------------

  Future<void> _editSegmentDialog(TransSegment seg) async {
    final controller = TextEditingController(text: seg.text);
    final newText = await showLSheet<String>(
      context: context,
      title: '编辑转写',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: controller, maxLines: 4, autofocus: true),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Get.back(), child: const Text('取消')),
              LButton(
                label: '保存',
                primary: true,
                onPressed: () => Get.back(result: controller.text),
              ),
            ],
          ),
        ],
      ),
    );
    if (newText == null || newText == seg.text) return;
    final patched = TransSegment(
      id: seg.id,
      beginTimeMs: seg.beginTimeMs,
      endTimeMs: seg.endTimeMs,
      speakerId: seg.speakerId,
      speakerName: seg.speakerName,
      text: newText,
    );
    try {
      await LynseApi.editSegments([patched]);
      if (mounted) {
        setState(() {
          _segments = _segments.map((e) => e.id == seg.id ? patched : e).toList();
        });
      }
    } catch (e) {
      Get.snackbar('保存失败', '$e');
    }
  }

  Future<void> _renameSpeakerDialog(TransSegment seg) async {
    final controller = TextEditingController(
      text: seg.speakerName ?? '发言人${seg.speakerId ?? ''}',
    );
    final newName = await showLSheet<String>(
      context: context,
      title: '重命名发言人',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: controller, autofocus: true),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Get.back(), child: const Text('取消')),
              LButton(
                label: '保存',
                primary: true,
                onPressed: () => Get.back(result: controller.text),
              ),
            ],
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    try {
      await LynseApi.renameSpeakers('task_$_fileId', [
        {'speakerId': seg.speakerId ?? '0', 'speakerName': newName},
      ]);
      if (mounted) {
        setState(() {
          _segments = _segments
              .map((e) => e.speakerId == seg.speakerId
                  ? TransSegment(
                      id: e.id,
                      beginTimeMs: e.beginTimeMs,
                      endTimeMs: e.endTimeMs,
                      speakerId: e.speakerId,
                      speakerName: newName,
                      text: e.text,
                    )
                  : e)
              .toList();
        });
      }
    } catch (e) {
      Get.snackbar('保存失败', '$e');
    }
  }

  // ------------------------------------------------------------------
  // 导出
  // ------------------------------------------------------------------

  void _showExportSheet() {
    showLSheet(
      context: context,
      title: '导出',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LLinkRow(
            icon: Icons.description_outlined,
            title: '导出为 Markdown',
            onTap: () {
              Get.back();
              _doExport('md');
            },
          ),
          LLinkRow(
            icon: Icons.text_snippet_outlined,
            title: '导出为纯文本',
            onTap: () {
              Get.back();
              _doExport('txt');
            },
          ),
          LLinkRow(
            icon: Icons.subtitles_outlined,
            title: '导出为 SRT 字幕',
            onTap: () {
              Get.back();
              _doExport('srt');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _doExport(String type) async {
    if (_fileId == null) return;
    try {
      final text = await LynseApi.exportText(
        fileId: _fileId!,
        kind: 'trans',
        exportType: type,
      );
      Get.snackbar('导出成功', '${text.length} 字符（保存到剪贴板）');
    } catch (e) {
      Get.snackbar('导出失败', '$e');
    }
  }
}

// ---------------------------------------------------------------------------
// 播放条
// ---------------------------------------------------------------------------

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({required this.localPath, required this.title});

  final String localPath;
  final String title;

  String _fmt(int ms) {
    final total = (ms / 1000).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final playback = PlaybackService.instance;
    return Obx(() {
      final active = playback.currentPath.value == localPath;
      final playing = active && playback.isPlaying.value;
      final pos = active ? playback.positionMs.value : 0;
      final dur = active ? playback.durationMs.value : 0;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: LSpacing.md, vertical: 8),
        child: Row(
          children: [
            LIconButton(
              icon: playing ? Icons.pause : Icons.play_arrow,
              tint: playing ? LColors.blue : LColors.sky,
              onPressed: () => playback.play(localPath, title: title),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: dur > 0
                  ? SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: LColors.blueDark,
                        inactiveTrackColor: LColors.line,
                        thumbColor: LColors.blueDark,
                      ),
                      child: Slider(
                        value: pos.clamp(0, dur).toDouble(),
                        max: dur.toDouble(),
                        onChanged: (v) => playback.seek(v.round()),
                      ),
                    )
                  : const Text('点击播放本条录音', style: LType.small),
            ),
            if (dur > 0) ...[
              Text('${_fmt(pos)} / ${_fmt(dur)}', style: LType.small),
              const SizedBox(width: 8),
            ],
            GestureDetector(
              onTap: active ? playback.cycleRate : null,
              child: LChip(label: '${playback.rate.value}x', tint: LColors.sky),
            ),
          ],
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// 转写段落（含播放进度高亮）
// ---------------------------------------------------------------------------

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    required this.seg,
    required this.speakerChanged,
    required this.speakerColor,
    required this.localLoaded,
    required this.onEdit,
    required this.onRenameSpeaker,
  });

  final TransSegment seg;
  final bool speakerChanged;
  final Color speakerColor;
  final bool localLoaded;
  final VoidCallback onEdit;
  final VoidCallback onRenameSpeaker;

  @override
  Widget build(BuildContext context) {
    final playback = PlaybackService.instance;
    return Obx(() {
      // 本地音频正在播放时，按当前进度高亮所在段落
      final playing = playback.isPlaying.value &&
          playback.positionMs.value >= (seg.beginTimeMs ?? 0) &&
          playback.positionMs.value < ((seg.endTimeMs ?? 0) + 500);
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (speakerChanged)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: speakerColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onRenameSpeaker,
                      child: Text(
                        seg.speakerName ?? '发言人${seg.speakerId ?? '?'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: speakerColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: onEdit,
                      child: const Icon(Icons.edit_outlined, size: 13, color: LColors.muted),
                    ),
                  ],
                ),
              ),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: double.infinity,
                color: playing ? LColors.sky : null,
                padding: playing ? const EdgeInsets.all(6) : null,
                child: Text(
                  seg.text,
                  style: LType.body.copyWith(height: 1.6),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

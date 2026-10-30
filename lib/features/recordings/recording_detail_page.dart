/// 录音详情页：播放条 + 转写 / 时间轴 / 纪要 三 tab + 编辑 + 导出。
///
/// 接入 RecordingDetailController（PRD-02 M1）：分段编辑（草稿防丢 +
/// 合规）、说话人改名、纪要编辑（乐观锁）、重新生成（轮询状态机）、
/// 初次转写轮询、编辑后内容本地导出。
library;

import 'package:dting/core/services/playback_service.dart';
import 'package:dting/features/recordings/recording_detail_controller.dart';
import 'package:dting/core/api/lynse_api.dart';
import 'package:dting/ui/components.dart';
import 'package:dting/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// 说话人色板（8 色）
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

class _RecordingDetailPageState extends State<RecordingDetailPage>
    with WidgetsBindingObserver {
  late final RecordingDetailController controller;
  late final String _tag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final args = Get.arguments;
    String title = '录音详情';
    String? localPath;
    String? fileId;
    if (args is Map) {
      title = args['title']?.toString() ?? title;
      localPath = args['localPath']?.toString();
      fileId = args['fileId']?.toString();
    }
    // 详情页不可叠加路由，但用 tag 隔离避免同 fileId 重复进入时的实例冲突
    _tag = 'rec_detail_${fileId ?? localPath ?? DateTime.now().microsecondsSinceEpoch}';
    controller = Get.put(
      RecordingDetailController(
        title: title,
        localPath: localPath,
        fileId: fileId,
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Get.delete<RecordingDetailController>(tag: _tag);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // F2-5：后台暂停轮询、回前台恢复
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      controller.pausePolling();
    } else if (state == AppLifecycleState.resumed) {
      controller.resumePolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Obx(() => Text(controller.title,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          actions: [
            if (controller.hasCloudFile)
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
        body: Obx(() {
          if (controller.loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              if (controller.localPath != null)
                _PlayerBar(
                    localPath: controller.localPath!,
                    title: controller.title),
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
          );
        }),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 转写 / 时间轴
  // ------------------------------------------------------------------

  Widget _buildTranscriptTab({required bool showSpeaker}) {
    if (!controller.hasCloudFile) {
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
    final phase = controller.transPhase.value;
    final error = controller.loadError.value;
    if (error != null && controller.segments.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(LSpacing.md),
        children: [
          LCard(
            child: Column(
              children: [
                LEmpty(icon: Icons.cloud_off_outlined, title: error),
                const SizedBox(height: 8),
                LButton(label: '重试', onPressed: controller.load),
              ],
            ),
          ),
        ],
      );
    }
    if (phase == ContentPhase.generating) {
      return ListView(
        padding: const EdgeInsets.all(LSpacing.md),
        children: const [
          LCard(
            child: LEmpty(
              icon: Icons.autorenew,
              title: '转写生成中…',
              message: '完成后自动刷新，可以离开这个页面',
            ),
          ),
        ],
      );
    }
    if (phase == ContentPhase.failed) {
      return ListView(
        padding: const EdgeInsets.all(LSpacing.md),
        children: [
          LCard(
            child: Column(
              children: [
                const LEmpty(
                  icon: Icons.error_outline,
                  title: '转写失败',
                  message: '内容不会丢失，可随时重试',
                ),
                const SizedBox(height: 8),
                LButton(label: '重试转写', onPressed: controller.startTranscription),
              ],
            ),
          ),
        ],
      );
    }
    if (controller.segments.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(LSpacing.md),
        children: [
          LCard(
            child: Column(
              children: [
                const LEmpty(
                  icon: Icons.notes,
                  title: '暂无转写内容',
                  message: '云端转写完成后，这里会显示可编辑的文本',
                ),
                const SizedBox(height: 8),
                LButton(
                  label: '发起转写',
                  primary: true,
                  onPressed: controller.startTranscription,
                ),
              ],
            ),
          ),
        ],
      );
    }
    String? lastSpeaker;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(LSpacing.md, 12, LSpacing.md, 24),
      itemCount: controller.segments.length,
      itemBuilder: (_, i) {
        final seg = controller.segments[i];
        final speakerChanged =
            showSpeaker && seg.speakerName != lastSpeaker;
        lastSpeaker = seg.speakerName;
        final speakerColor = _speakerColors[
            (int.tryParse(seg.speakerId ?? '0') ?? 0)
                .clamp(0, _speakerColors.length - 1)];
        return _SegmentTile(
          seg: seg,
          speakerChanged: speakerChanged,
          speakerColor: speakerColor,
          localLoaded: controller.localPath != null,
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
    if (!controller.hasCloudFile) {
      return ListView(
        padding: const EdgeInsets.all(LSpacing.md),
        children: const [
          LCard(
            child: LEmpty(
                icon: Icons.auto_awesome_outlined, title: '同步并转写后可生成 AI 纪要'),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(LSpacing.md, 12, LSpacing.md, 24),
      children: [
        // 大纲
        LSectionHeading(
          label: '大纲',
          trailing: _phaseTrailing(
            phase: controller.outlinePhase.value,
            hasContent: controller.outline.value != null,
            onRegenerate: () => _pickTemplateAndRegenerate(isConclusion: false),
            onEdit: controller.outline.value == null
                ? null
                : _editOutlineDialog,
          ),
        ),
        const SizedBox(height: 6),
        _OutlineCard(
          outline: controller.outline.value,
          phase: controller.outlinePhase.value,
          onRetry: () => controller.regenerate(isConclusion: false),
        ),
        const SizedBox(height: LSpacing.md),
        // 总结
        LSectionHeading(
          label: '总结',
          trailing: _phaseTrailing(
            phase: controller.conclusionPhase.value,
            hasContent: controller.conclusions.isNotEmpty,
            onRegenerate: () => _pickTemplateAndRegenerate(isConclusion: true),
            onEdit: null,
          ),
        ),
        const SizedBox(height: 6),
        if (controller.conclusions.isEmpty &&
            controller.conclusionPhase.value == ContentPhase.idle)
          const LCard(
            child: LEmpty(
              icon: Icons.auto_awesome_outlined,
              title: '暂无总结',
              message: '转写完成后选择模板生成',
            ),
          )
        else if (controller.conclusionPhase.value == ContentPhase.generating &&
            controller.conclusions.isEmpty)
          const LCard(
            child: LEmpty(
              icon: Icons.autorenew,
              title: '总结生成中…',
              message: '完成后自动刷新',
            ),
          )
        else if (controller.conclusionPhase.value == ContentPhase.failed &&
            controller.conclusions.isEmpty)
          LCard(
            child: Column(
              children: [
                const LEmpty(
                    icon: Icons.error_outline,
                    title: '总结生成失败',
                    message: '内容不会丢失，可随时重试'),
                const SizedBox(height: 8),
                LButton(
                  label: '重试',
                  onPressed: () =>
                      controller.regenerate(isConclusion: true),
                ),
              ],
            ),
          )
        else
          ...controller.conclusions.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.templateName.isEmpty ? '总结' : c.templateName,
                            style: LType.body
                                .copyWith(fontWeight: FontWeight.w600, color: LColors.blueDark),
                          ),
                        ),
                        InkWell(
                          onTap: () => _editConclusionDialog(c),
                          child: const Icon(Icons.edit_outlined,
                              size: 15, color: LColors.muted),
                        ),
                      ],
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
        // 行动项（PRD-01 范围：仅展示，更新走联调）
        const LSectionHeading(label: '行动项'),
        const SizedBox(height: 6),
        if (controller.todos.isEmpty)
          const LCard(child: LEmpty(icon: Icons.checklist, title: '暂无行动项'))
        else
          LCard(
            child: Column(
              children: controller.todos
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
                          // TODO(联调): 后端确认后接 updateTodo（PRD-01 范围）
                          Get.snackbar('提示', '行动项更新将在联调后启用');
                        },
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  /// 区块标题右侧动作：生成中转圈 / 有内容给编辑+重新生成
  Widget? _phaseTrailing({
    required ContentPhase phase,
    required bool hasContent,
    required VoidCallback onRegenerate,
    VoidCallback? onEdit,
  }) {
    if (phase == ContentPhase.generating) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasContent && onEdit != null)
          InkWell(
            onTap: onEdit,
            child: const Icon(Icons.edit_outlined, size: 15, color: LColors.muted),
          ),
        if (hasContent) const SizedBox(width: 10),
        InkWell(
          onTap: onRegenerate,
          child: const Icon(Icons.refresh, size: 17, color: LColors.muted),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 编辑弹窗（F2-1 分段 / F2-4 纪要 / F2-2 说话人）
  // ------------------------------------------------------------------

  Future<void> _editSegmentDialog(TransSegment seg) async {
    final textController = TextEditingController(text: seg.text);
    final draft = controller.draftFor(seg.id);
    final newText = await showLSheet<String>(
      context: context,
      title: '编辑转写',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (draft != null && draft != seg.text)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LLinkRow(
                icon: Icons.history,
                title: '检测到未保存的修改',
                subtitle: '点击恢复上次编辑的内容',
                trailing: const Icon(Icons.restore, size: 16, color: LColors.blueDark),
                onTap: () {
                  textController.text = draft;
                  Get.back();
                },
              ),
            ),
          TextField(
            controller: textController,
            maxLines: 6,
            autofocus: true,
            onChanged: (v) => controller.saveDraft(seg.id, v),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Get.back(), child: const Text('取消')),
              LButton(
                label: '保存',
                primary: true,
                onPressed: () => Get.back(result: textController.text),
              ),
            ],
          ),
        ],
      ),
    );
    if (newText == null || newText == seg.text) return;
    final outcome = await controller.editSegment(seg, newText);
    if (outcome == EditOutcome.conflict) {
      await _conflictDialog(
        kind: '转写内容',
        onReload: controller.load,
        onRedo: _reloadThenEditLatest,
      );
    }
  }

  Future<void> _reloadThenEditLatest() async {
    await controller.load();
    if (controller.segments.isNotEmpty && mounted) {
      await _editSegmentDialog(controller.segments.first);
    }
  }

  Future<void> _editConclusionDialog(Conclusion c) async {
    final textController = TextEditingController(text: c.text);
    final newText = await showLSheet<String>(
      context: context,
      title: '编辑总结',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: textController, maxLines: 10, autofocus: true),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Get.back(), child: const Text('取消')),
              LButton(
                label: '保存',
                primary: true,
                onPressed: () => Get.back(result: textController.text),
              ),
            ],
          ),
        ],
      ),
    );
    if (newText == null || newText == c.text) return;
    final outcome = await controller.editConclusionText(c, newText);
    if (outcome == EditOutcome.conflict) {
      await _conflictDialog(
        kind: '总结',
        onReload: controller.load,
        onRedo: controller.load,
      );
    }
  }

  Future<void> _editOutlineDialog() async {
    final current = controller.outline.value;
    if (current == null) return;
    final textController = TextEditingController(text: current.text);
    final newText = await showLSheet<String>(
      context: context,
      title: '编辑大纲',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: textController, maxLines: 10, autofocus: true),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Get.back(), child: const Text('取消')),
              LButton(
                label: '保存',
                primary: true,
                onPressed: () => Get.back(result: textController.text),
              ),
            ],
          ),
        ],
      ),
    );
    if (newText == null || newText == current.text) return;
    final outcome = await controller.editOutlineText(newText);
    if (outcome == EditOutcome.conflict) {
      await _conflictDialog(
        kind: '大纲',
        onReload: controller.load,
        onRedo: controller.load,
      );
    }
  }

  /// F2-4 409 冲突：查看最新 / 基于最新重做（重开编辑框）
  Future<void> _conflictDialog({
    required String kind,
    required Future<void> Function() onReload,
    required Future<void> Function() onRedo,
  }) async {
    await showLSheet(
      context: context,
      title: '$kind已在其他端被修改',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LLinkRow(
            icon: Icons.sync,
            title: '查看最新内容',
            subtitle: '放弃本次修改，刷新为最新版本',
            onTap: () {
              Get.back();
              onReload();
            },
          ),
          LLinkRow(
            icon: Icons.edit_note,
            title: '基于最新内容重做',
            subtitle: '刷新后重新打开编辑',
            onTap: () {
              Get.back();
              onRedo();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _renameSpeakerDialog(TransSegment seg) async {
    final textController = TextEditingController(
      text: seg.speakerName ?? '发言人${seg.speakerId ?? ''}',
    );
    final newName = await showLSheet<String>(
      context: context,
      title: '重命名发言人',
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('该发言人在本录音中的所有段落将同步更新', style: LType.small),
          const SizedBox(height: 10),
          TextField(controller: textController, autofocus: true),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Get.back(), child: const Text('取消')),
              LButton(
                label: '保存',
                primary: true,
                onPressed: () => Get.back(result: textController.text),
              ),
            ],
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    await controller.renameSpeaker(seg.speakerId, newName);
  }

  // ------------------------------------------------------------------
  // F2-3 模板选择 + 重新生成
  // ------------------------------------------------------------------

  Future<void> _pickTemplateAndRegenerate({required bool isConclusion}) async {
    final templates = await controller.loadTemplates();
    String? templateId;
    if (templates.isNotEmpty && mounted) {
      templateId = await showLSheet<String>(
        context: context,
        title: '选择生成模板',
        builder: (ctx) => ListView(
          shrinkWrap: true,
          children: templates
              .map((t) => LLinkRow(
                    icon: Icons.description_outlined,
                    title: t.name,
                    subtitle: t.category.isEmpty ? null : t.category,
                    onTap: () => Get.back(result: t.id),
                  ))
              .toList(),
        ),
      );
    }
    await controller.regenerate(
      isConclusion: isConclusion,
      templateId: templateId,
    );
  }

  // ------------------------------------------------------------------
  // 导出（F2-6.2：内容源为当前编辑后数据，本地拼接）
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
              _doExport(_ExportFormat.md);
            },
          ),
          LLinkRow(
            icon: Icons.text_snippet_outlined,
            title: '导出为纯文本',
            onTap: () {
              Get.back();
              _doExport(_ExportFormat.txt);
            },
          ),
          LLinkRow(
            icon: Icons.subtitles_outlined,
            title: '导出为 SRT 字幕',
            onTap: () {
              Get.back();
              _doExport(_ExportFormat.srt);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _doExport(_ExportFormat format) async {
    final text = _buildExportText(format);
    await Clipboard.setData(ClipboardData(text: text));
    Get.snackbar('导出成功', '${text.length} 字符（已复制到剪贴板）');
  }

  String _fmtClock(int ms, {bool srt = false}) {
    final total = (ms / 1000).round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (srt) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')},000';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// F2-6.2：导出内容 = 当前内存中（已编辑）的数据，所见即所得
  String _buildExportText(_ExportFormat format) {
    final buf = StringBuffer();
    final includeSummary = format != _ExportFormat.srt;
    if (includeSummary) {
      buf.writeln('# ${controller.title}');
      buf.writeln();
      final outline = controller.outline.value;
      if (outline != null && outline.text.isNotEmpty) {
        buf.writeln('## 大纲');
        buf.writeln(outline.text);
        buf.writeln();
      }
      for (final c in controller.conclusions) {
        final name = c.templateName.isEmpty ? '总结' : c.templateName;
        buf.writeln('## $name');
        buf.writeln(c.text);
        buf.writeln();
      }
      if (controller.segments.isNotEmpty) {
        buf.writeln('## 转写');
        buf.writeln();
      }
    }
    for (var i = 0; i < controller.segments.length; i++) {
      final seg = controller.segments[i];
      final speaker = seg.speakerName ?? '发言人${seg.speakerId ?? i}';
      switch (format) {
        case _ExportFormat.srt:
          final begin = _fmtClock(seg.beginTimeMs ?? 0, srt: true);
          final end = _fmtClock(seg.endTimeMs ?? (seg.beginTimeMs ?? 0) + 2000,
              srt: true);
          buf
            ..writeln('${i + 1}')
            ..writeln('$begin --> $end')
            ..writeln(seg.text)
            ..writeln();
        case _ExportFormat.md:
          final t = seg.beginTimeMs != null ? '（${_fmtClock(seg.beginTimeMs!)}）' : '';
          buf
            ..writeln('**$speaker**$t')
            ..writeln(seg.text)
            ..writeln();
        case _ExportFormat.txt:
          buf.writeln('$speaker：${seg.text}');
      }
    }
    return buf.toString().trimRight();
  }
}

enum _ExportFormat { md, txt, srt }

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
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
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
// 大纲卡片（含生成中/失败态）
// ---------------------------------------------------------------------------

class _OutlineCard extends StatelessWidget {
  const _OutlineCard({
    required this.outline,
    required this.phase,
    required this.onRetry,
  });

  final Outline? outline;
  final ContentPhase phase;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (outline != null) {
      return LCard(
        child: Text(
          outline!.text,
          style: LType.muted.copyWith(height: 1.6, color: LColors.text),
        ),
      );
    }
    if (phase == ContentPhase.generating) {
      return const LCard(
        child: LEmpty(
          icon: Icons.autorenew,
          title: '大纲生成中…',
          message: '完成后自动刷新',
        ),
      );
    }
    if (phase == ContentPhase.failed) {
      return LCard(
        child: Column(
          children: [
            const LEmpty(
                icon: Icons.error_outline,
                title: '大纲生成失败',
                message: '内容不会丢失，可随时重试'),
            const SizedBox(height: 8),
            LButton(label: '重试', onPressed: onRetry),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
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
                      decoration:
                          BoxDecoration(color: speakerColor, shape: BoxShape.circle),
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
                      child: const Icon(Icons.edit_outlined,
                          size: 13, color: LColors.muted),
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

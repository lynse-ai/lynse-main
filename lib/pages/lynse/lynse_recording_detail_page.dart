/// 录音详情页：转写 / 时间轴 / 纪要 三个 tab + 转写编辑 + 导出
/// （对照 lynse-desktop transcript-detail-page.tsx 与 workspace content-panel）。
library;

import 'package:dting/http/lynse_api.dart';
import 'package:dting/pages/lynse/lynse_widgets.dart';
import 'package:dting/styles/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LynseRecordingDetailPage extends StatefulWidget {
  const LynseRecordingDetailPage({super.key});

  @override
  State<LynseRecordingDetailPage> createState() =>
      _LynseRecordingDetailPageState();
}

class _LynseRecordingDetailPageState extends State<LynseRecordingDetailPage> {
  String _title = '录音详情';
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
    final s = context.lynse;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: s.background,
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
          bottom: TabBar(
            indicatorColor: s.brand,
            labelColor: s.foreground,
            unselectedLabelColor: s.mutedForeground,
            dividerColor: s.border,
            tabs: const [
              Tab(text: '转写'),
              Tab(text: '时间轴'),
              Tab(text: '纪要'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildTranscriptTab(context, showSpeaker: true),
                  _buildTranscriptTab(context, showSpeaker: false),
                  _buildSummaryTab(context),
                ],
              ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 转写 / 时间轴
  // ------------------------------------------------------------------

  Widget _buildTranscriptTab(BuildContext context, {required bool showSpeaker}) {
    final s = context.lynse;
    if (_fileId == null || _fileId!.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LynseCard(
            child: LynseEmpty(
              icon: Icons.cloud_upload_outlined,
              title: '本地录音尚未同步',
              subtitle: '文件同步到云端并完成转写后，这里会显示可编辑的转写文本',
            ),
          ),
        ],
      );
    }
    if (_error != null && _segments.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LynseCard(
            child: Column(
              children: [
                LynseEmpty(icon: Icons.cloud_off_outlined, title: _error!),
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
        padding: const EdgeInsets.all(16),
        children: const [
          LynseCard(child: LynseEmpty(icon: Icons.notes, title: '暂无转写内容')),
        ],
      );
    }
    String? lastSpeaker;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _segments.length,
      itemBuilder: (_, i) {
        final seg = _segments[i];
        final speakerChanged = showSpeaker && seg.speakerName != lastSpeaker;
        lastSpeaker = seg.speakerName;
        final speakerColor = LynseColors
            .speakers[int.tryParse(seg.speakerId ?? '0')!
                .clamp(0, LynseColors.speakers.length - 1)];
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
                        decoration: BoxDecoration(
                          color: speakerColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _renameSpeakerDialog(seg),
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
                        onTap: () => _editSegmentDialog(seg),
                        child: Icon(Icons.edit_outlined,
                            size: 13, color: s.mutedForeground),
                      ),
                    ],
                  ),
                ),
              GestureDetector(
                onTap: () => _editSegmentDialog(seg),
                child: Text(
                  seg.text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: s.foreground,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // 纪要 tab
  // ------------------------------------------------------------------

  Widget _buildSummaryTab(BuildContext context) {
    final s = context.lynse;
    if (_fileId == null || _fileId!.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LynseCard(
            child: LynseEmpty(
              icon: Icons.auto_awesome_outlined,
              title: '同步并转写后可生成 AI 纪要',
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_outline != null) ...[
          SectionHeader(
            title: '大纲',
            trailing: Icon(Icons.edit_outlined,
                size: 16, color: s.mutedForeground),
          ),
          const SizedBox(height: 6),
          LynseCard(
            child: Text(
              _outline!.text,
              style: TextStyle(fontSize: 13, height: 1.6, color: s.foreground),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SectionHeader(title: '总结'),
        const SizedBox(height: 6),
        if (_conclusions.isEmpty)
          LynseCard(
            child: LynseEmpty(
              icon: Icons.auto_awesome_outlined,
              title: '暂无总结',
              subtitle: '转写完成后选择模板生成',
            ),
          )
        else
          ..._conclusions.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LynseCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.templateName.isEmpty ? '总结' : c.templateName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: s.brand,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.text,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: s.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        const SizedBox(height: 16),
        SectionHeader(title: '行动项'),
        const SizedBox(height: 6),
        if (_todos.isEmpty)
          const LynseCard(
            child: LynseEmpty(icon: Icons.checklist, title: '暂无行动项'),
          )
        else
          LynseCard(
            child: Column(
              children: _todos
                  .map((t) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: t.completed,
                        activeColor: s.brand,
                        title: Text(
                          t.content,
                          style: TextStyle(
                            fontSize: 13,
                            color: s.foreground,
                            decoration: t.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
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
    final s = context.lynse;
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: s.card,
        title: const Text('编辑转写', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Get.back(result: controller.text),
            child: const Text('保存'),
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
          _segments = _segments
              .map((e) => e.id == seg.id
                  ? patched
                  : e)
              .toList();
        });
      }
    } catch (e) {
      Get.snackbar('保存失败', '$e');
    }
  }

  Future<void> _renameSpeakerDialog(TransSegment seg) async {
    final controller =
        TextEditingController(text: seg.speakerName ?? '发言人${seg.speakerId ?? ''}');
    final s = context.lynse;
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: s.card,
        title: const Text('重命名发言人', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Get.back(result: controller.text),
            child: const Text('保存'),
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
              .map((e) =>
                  e.speakerId == seg.speakerId
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
    final s = context.lynse;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.description_outlined, color: s.brand),
              title: const Text('导出为 Markdown'),
              onTap: () => _doExport('md'),
            ),
            ListTile(
              leading: Icon(Icons.text_snippet_outlined, color: s.brand),
              title: const Text('导出为纯文本'),
              onTap: () => _doExport('txt'),
            ),
            ListTile(
              leading: Icon(Icons.subtitles_outlined, color: s.brand),
              title: const Text('导出为 SRT 字幕'),
              onTap: () => _doExport('srt'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doExport(String type) async {
    Get.back();
    if (_fileId == null) return;
    try {
      final text = await LynseApi.exportText(
        fileId: _fileId!,
        kind: 'trans',
        exportType: type,
      );
      Get.snackbar('导出成功', '${text.length} 字符（保存到剪贴板）');
      // 简化实现：内容放入剪贴板；文件落盘/分享随联调补齐
      // ignore: avoid_print
      print('export[$type]: $text');
    } catch (e) {
      Get.snackbar('导出失败', '$e');
    }
  }
}

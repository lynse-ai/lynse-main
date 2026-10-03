/// 录音详情控制器：PRD-02 M1 转写后处理闭环的客户端状态机。
///
/// - F2-5：转写/总结/概要各自 idle/generating/success/failed，
///   统一用 [PollingTask] 轮询；任务流水并入 TaskCenter。
/// - F2-1：分段编辑（合规校验 + Hive 草稿防丢失）。
/// - F2-2：说话人全局改名。
/// - F2-3：总结/概要重新生成（含 402 积分不足分支）。
/// - F2-4：纪要编辑（乐观锁 version，409 冲突交页面处理）。
library;

import 'package:dting/core/services/polling_task.dart';
import 'package:dting/core/services/task_center.dart';
import 'package:dting/core/services/trans_draft_store.dart';
import 'package:dting/core/api/lynse_api.dart';
import 'package:dting/ui/components.dart';
import 'package:dting/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 单类内容生命周期（PRD-02 F2-5 四态）
enum ContentPhase { idle, generating, success, failed }

/// 编辑保存结果（F2-1/F2-4；conflict 由页面弹 409 对话框）
enum EditOutcome { ok, conflict, rejected, empty, tooLong, error }

class RecordingDetailController extends GetxController {
  RecordingDetailController({
    required this.title,
    this.localPath,
    this.fileId,
  });

  final String title;
  final String? localPath;
  final String? fileId;

  final TransDraftStore _drafts = TransDraftStore();
  TaskCenter get _tasks => TaskCenter.instance;

  // 四态状态机（导图在助手版详情页不存在，不设状态）
  final transPhase = ContentPhase.idle.obs;
  final conclusionPhase = ContentPhase.idle.obs;
  final outlinePhase = ContentPhase.idle.obs;

  final loading = true.obs;
  final loadError = Rxn<String>();
  final segments = <TransSegment>[].obs;
  final conclusions = <Conclusion>[].obs;
  final outline = Rxn<Outline>();
  final todos = <ActionTodo>[].obs;

  PollingTask? _transcribePolling;
  PollingTask? _aiPolling;
  String? _pendingTranscribeTaskId;

  bool get hasCloudFile => fileId != null && fileId!.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _transcribePolling?.dispose();
    _aiPolling?.dispose();
    super.onClose();
  }

  /// App 生命周期挂接（F2-5：后台暂停、回前台恢复）
  void pausePolling() {
    _transcribePolling?.pause();
    _aiPolling?.pause();
  }

  void resumePolling() {
    _transcribePolling?.resume();
    _aiPolling?.resume();
  }

  // ------------------------------------------------------------------
  // 数据加载与冷启恢复
  // ------------------------------------------------------------------

  Future<void> load() async {
    if (!hasCloudFile) {
      loading.value = false;
      return;
    }
    loading.value = true;
    loadError.value = null;
    try {
      // F2-5：冷启恢复——有进行中的转写任务则先恢复轮询
      final pending = _drafts.loadPendingTranscribeTaskId(fileId: fileId!);
      if (pending != null && segments.isEmpty) {
        _pendingTranscribeTaskId = pending;
        transPhase.value = ContentPhase.generating;
        _startTranscribePolling();
      }
      final segs = await LynseApi.fetchTranscription(fileId!);
      final cons = await LynseApi.conclusions(fileId!);
      final out = await LynseApi.outline(fileId!);
      final tds = await LynseApi.todos(fileId!);
      segments.assignAll(segs);
      conclusions.assignAll(cons);
      outline.value = out;
      todos.assignAll(tds);
      if (segments.isNotEmpty) {
        transPhase.value = ContentPhase.success;
      } else if (_pendingTranscribeTaskId == null) {
        transPhase.value = ContentPhase.idle;
      }
      conclusionPhase.value =
          conclusions.isEmpty ? ContentPhase.idle : ContentPhase.success;
      outlinePhase.value =
          outline.value == null ? ContentPhase.idle : ContentPhase.success;
    } catch (e) {
      loadError.value = '云端内容加载失败：$e';
    } finally {
      loading.value = false;
    }
  }

  Future<void> _refreshTranscription() async {
    try {
      final segs = await LynseApi.fetchTranscription(fileId!);
      segments.assignAll(segs);
      transPhase.value = ContentPhase.success;
    } catch (e) {
      loadError.value = '转写结果拉取失败：$e';
    }
  }

  Future<void> _refreshConclusions() async {
    try {
      conclusions.assignAll(await LynseApi.conclusions(fileId!));
      conclusionPhase.value =
          conclusions.isEmpty ? ContentPhase.idle : ContentPhase.success;
    } catch (e) {
      debugPrint('[Detail] 总结刷新失败: $e');
    }
  }

  Future<void> _refreshOutline() async {
    try {
      outline.value = await LynseApi.outline(fileId!);
      outlinePhase.value =
          outline.value == null ? ContentPhase.idle : ContentPhase.success;
    } catch (e) {
      debugPrint('[Detail] 大纲刷新失败: $e');
    }
  }

  // ------------------------------------------------------------------
  // F2-5/F2-6.1 初次转写 + 轮询
  // ------------------------------------------------------------------

  Future<void> startTranscription() async {
    if (!hasCloudFile) return;
    try {
      transPhase.value = ContentPhase.generating;
      final taskId = await LynseApi.startTranscription(fileId!);
      _pendingTranscribeTaskId = taskId;
      _drafts.savePendingTranscribe(fileId: fileId!, taskId: taskId);
      final entry = await _tasks.submit(
        TaskType.transcribe,
        '转写：$title',
        refId: fileId,
      );
      _startTranscribePolling(entry);
    } on LynseApiException catch (e) {
      transPhase.value = ContentPhase.failed;
      _showApiError(e);
    }
  }

  /// [entry] 为 null 时是冷启恢复路径（内存任务流水已不在，只恢复轮询）。
  void _startTranscribePolling([TaskEntry? entry]) {
    _transcribePolling?.dispose();
    _transcribePolling = PollingTask(
      probe: () => LynseApi.transcriptionDone(fileId!),
      onComplete: () async {
        _drafts.clearPendingTranscribe(fileId: fileId!);
        _pendingTranscribeTaskId = null;
        if (entry != null) {
          await _tasks.advance(entry, status: TaskStatus.success, progress: 100);
        }
        await _refreshTranscription();
      },
      onError: (e) async {
        // -2 = 服务端明确失败；-1 网络错误由 PollingTask 退避重试
        if (e is LynseApiException && e.code == -2) {
          _transcribePolling?.dispose();
          _transcribePolling = null;
          _drafts.clearPendingTranscribe(fileId: fileId!);
          _pendingTranscribeTaskId = null;
          transPhase.value = ContentPhase.failed;
          if (entry != null) {
            await _tasks.advance(entry,
                status: TaskStatus.failed, error: e.message);
          }
        }
      },
    )..start();
  }

  // ------------------------------------------------------------------
  // F2-3 重新生成（CONCLUSION / OUTLINE）
  // ------------------------------------------------------------------

  Future<void> regenerate({required bool isConclusion, String? templateId}) async {
    if (!hasCloudFile) return;
    final phase = isConclusion ? conclusionPhase : outlinePhase;
    final type = isConclusion ? 'CONCLUSION' : 'OUTLINE';
    try {
      phase.value = ContentPhase.generating;
      final taskId = await LynseApi.startAiTask(
        fileId!,
        aiTaskType: type,
        templateId: templateId,
      );
      final entry = await _tasks.submit(
        TaskType.summarize,
        '生成${isConclusion ? '总结' : '大纲'}：$title',
        refId: fileId,
      );
      _aiPolling?.dispose();
      _aiPolling = PollingTask(
        probe: () => LynseApi.aiTaskDone(fileId!, taskId, aiTaskType: type),
        onComplete: () async {
          await _tasks.advance(entry, status: TaskStatus.success, progress: 100);
          if (isConclusion) {
            await _refreshConclusions();
          } else {
            await _refreshOutline();
          }
        },
        onError: (e) async {
          if (e is LynseApiException && e.code == -2) {
            _aiPolling?.dispose();
            _aiPolling = null;
            phase.value = ContentPhase.failed;
            await _tasks.advance(entry, status: TaskStatus.failed, error: e.message);
          }
        },
      )..start();
    } on LynseApiException catch (e) {
      phase.value =
          (isConclusion ? conclusions.isEmpty : outline.value == null)
              ? ContentPhase.failed
              : ContentPhase.success;
      _showApiError(e);
    }
  }

  // ------------------------------------------------------------------
  // F2-1 分段编辑（合规 + 草稿）
  // ------------------------------------------------------------------

  String? draftFor(String recordId) =>
      hasCloudFile ? _drafts.loadFreshDraft(fileId: fileId!, recordId: recordId) : null;

  void saveDraft(String recordId, String text) {
    if (!hasCloudFile) return;
    _drafts.saveDraft(fileId: fileId!, recordId: recordId, text: text);
  }

  void clearDraft(String recordId) {
    if (!hasCloudFile) return;
    _drafts.clearDraft(fileId: fileId!, recordId: recordId);
  }

  Future<EditOutcome> editSegment(TransSegment seg, String newText) async {
    final outcome = _validateText(newText);
    if (outcome != null) return outcome;
    if (!await LynseApi.checkTextValidity(newText)) {
      return EditOutcome.rejected;
    }
    final patched = seg.copyWith(text: newText);
    try {
      await LynseApi.editSegments([patched]);
      final i = segments.indexWhere((e) => e.id == seg.id);
      if (i >= 0) segments[i] = patched;
      clearDraft(seg.id);
      return EditOutcome.ok;
    } on LynseApiException catch (e) {
      if (e.code == 409) return EditOutcome.conflict;
      _showApiError(e);
      return EditOutcome.error;
    }
  }

  // ------------------------------------------------------------------
  // F2-2 说话人全局改名
  // ------------------------------------------------------------------

  Future<EditOutcome> renameSpeaker(String? speakerId, String newName) async {
    if (speakerId == null) {
      Get.snackbar('提示', '该段落缺少说话人标识，暂不支持改名');
      return EditOutcome.error;
    }
    // TODO(联调): 已完成转写的历史任务无 taskId 来源，暂用 pending 或合成 key；
    // 后端确认按 fileId 全局改名的语义后对齐。
    final taskId = _pendingTranscribeTaskId ?? 'task_$fileId';
    try {
      await LynseApi.renameSpeakers(taskId, [
        {'speakerId': speakerId, 'speakerName': newName},
      ]);
      segments.assignAll(segments
          .map((e) => e.speakerId == speakerId
              ? TransSegment(
                  id: e.id,
                  beginTimeMs: e.beginTimeMs,
                  endTimeMs: e.endTimeMs,
                  beginTimeStr: e.beginTimeStr,
                  endTimeStr: e.endTimeStr,
                  speakerId: e.speakerId,
                  speakerName: newName,
                  text: e.text,
                )
              : e)
          .toList());
      return EditOutcome.ok;
    } on LynseApiException catch (e) {
      _showApiError(e);
      return EditOutcome.error;
    }
  }

  // ------------------------------------------------------------------
  // F2-4 纪要编辑（乐观锁）
  // ------------------------------------------------------------------

  Future<EditOutcome> editConclusionText(Conclusion c, String newText) async {
    final outcome = _validateText(newText);
    if (outcome != null) return outcome;
    if (!await LynseApi.checkTextValidity(newText)) {
      return EditOutcome.rejected;
    }
    try {
      await LynseApi.editConclusion(c.id, newText, c.version);
      final i = conclusions.indexWhere((e) => e.id == c.id);
      if (i >= 0) {
        conclusions[i] = Conclusion(
          id: c.id,
          fileId: c.fileId,
          templateId: c.templateId,
          templateName: c.templateName,
          text: newText,
          contentFormat: c.contentFormat,
          version: c.version + 1,
        );
      }
      return EditOutcome.ok;
    } on LynseApiException catch (e) {
      if (e.code == 409) return EditOutcome.conflict;
      _showApiError(e);
      return EditOutcome.error;
    }
  }

  Future<EditOutcome> editOutlineText(String newText) async {
    final current = outline.value;
    if (current == null) return EditOutcome.error;
    final outcome = _validateText(newText);
    if (outcome != null) return outcome;
    if (!await LynseApi.checkTextValidity(newText)) {
      return EditOutcome.rejected;
    }
    try {
      // version 携带给后端做乐观锁；后端暂不支持该字段时容忍（PRD-02 E5）
      await LynseApi.editOutline(current.id, newText, version: current.version);
      outline.value = Outline(
        id: current.id,
        fileId: current.fileId,
        text: newText,
        contentFormat: current.contentFormat,
        version: current.version + 1,
      );
      return EditOutcome.ok;
    } on LynseApiException catch (e) {
      if (e.code == 409) return EditOutcome.conflict;
      _showApiError(e);
      return EditOutcome.error;
    }
  }

  // ------------------------------------------------------------------
  // 模板（F2-3 重新生成时选择）
  // ------------------------------------------------------------------

  Future<List<PromptTemplate>> loadTemplates() async {
    try {
      return await LynseApi.promptTemplates();
    } on LynseApiException {
      return const [];
    }
  }

  // ------------------------------------------------------------------
  // 内部工具
  // ------------------------------------------------------------------

  EditOutcome? _validateText(String text) {
    if (text.trim().isEmpty) {
      Get.snackbar('提示', '内容不能为空');
      return EditOutcome.empty;
    }
    if (text.length > 5000) {
      Get.snackbar('提示', '单段内容最长 5000 字');
      return EditOutcome.tooLong;
    }
    return null;
  }

  void _showApiError(LynseApiException e) {
    // TODO(联调): 402 积分不足——购买体系已随重构移除，
    // 后端就绪后接 PRD-01 的购买引导流程（sheet 内跳购买）。
    if (e.code == 402) {
      _showPointsSheet();
      return;
    }
    Get.snackbar('操作失败', e.message);
  }

  /// F2-3 402 积分不足：规范 sheet 提示（购买入口联调后接入）
  void _showPointsSheet() {
    final ctx = Get.context;
    if (ctx == null) return;
    showLSheet<void>(
      context: ctx,
      title: '积分不足',
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LEmpty(
            icon: Icons.stars_outlined,
            title: '积分不足',
            message: '生成 AI 内容需要消耗积分\n购买入口将在联调后开放',
          ),
          const SizedBox(height: LSpacing.md),
          SizedBox(
            width: double.infinity,
            child: LButton(label: '知道了', onPressed: () => Get.back()),
          ),
        ],
      ),
    );
  }
}

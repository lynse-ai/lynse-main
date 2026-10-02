/// 助手服务：会话管理 + 后端抽象（Mock 先行，LynseApi 契约后切换）。
///
/// MockAssistantBackend 用本地真数据回答（设备状态/最近录音/今日概览），
/// 保证界面与数据流完全真实，后端接通后只需替换 backend 实现。
library;

import 'dart:convert';

import 'package:dting/core/hardware/models.dart';
import 'package:dting/core/services/device_session_controller.dart';
import 'package:dting/core/services/recording_library.dart';
import 'package:dting/core/services/task_center.dart';
import 'package:dting/utils/local_sqldb.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';

/// 助手消息
class AssistantMessage {
  final int? id;
  final String role; // user | assistant
  final String text;
  final AssistantToolCard? toolCard; // 结构化工具卡（可与文本并存）
  final DateTime createdAt;

  const AssistantMessage({
    this.id,
    required this.role,
    required this.text,
    this.toolCard,
    required this.createdAt,
  });
}

/// 结构化工具卡（设备状态 / 录音引用 / 任务状态）
class AssistantToolCard {
  final String kind; // device | recordings | tasks | transcribe
  final Map<String, dynamic> payload;

  const AssistantToolCard({required this.kind, required this.payload});
}

/// 助手后端接口：Lynse 后端对话端点就绪后实现 [AssistantBackend] 替换 Mock。
abstract interface class AssistantBackend {
  Future<AssistantMessage> respond(String userText, {String? scopeRecordingPath});
}

class AssistantService extends GetxController {
  AssistantService._();

  static AssistantService get instance => Get.find<AssistantService>();

  static AssistantService init() {
    if (Get.isRegistered<AssistantService>()) return Get.find<AssistantService>();
    final c = AssistantService._();
    Get.put(c, permanent: true);
    return c;
  }

  /// 当前后端（联调后切换为 LynseBackend）
  AssistantBackend backend = MockAssistantBackend();

  Database? get _db => SqlDBHelper.database;

  final messages = <AssistantMessage>[].obs;
  final thinking = false.obs;
  int? _sessionId;

  /// shell 启动时调用：恢复最近会话
  void bootstrap() {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final db = _db;
    if (db == null) return;
    try {
      final sessions = await db.query(
        'chat_sessions',
        orderBy: 'updatedAt DESC',
        limit: 1,
      );
      if (sessions.isEmpty) {
        _sessionId = null;
        return;
      }
      _sessionId = sessions.first['id'] as int;
      final rows = await db.query(
        'chat_messages',
        where: 'sessionId = ?',
        whereArgs: [_sessionId],
        orderBy: 'createdAt ASC',
        limit: 100,
      );
      messages.assignAll(rows.map(_rowToMessage));
    } catch (e) {
      debugPrint('[AssistantService] 会话恢复失败: $e');
    }
  }

  Future<int> _ensureSession() async {
    if (_sessionId != null) return _sessionId!;
    final db = _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    _sessionId = await db!.insert('chat_sessions', {
      'title': '助手会话',
      'scope': 'global',
      'createdAt': now,
      'updatedAt': now,
    });
    return _sessionId!;
  }

  /// 发送一条用户消息并取得回复（持久化双边消息）。
  Future<void> send(String text, {String? scopeRecordingPath}) async {
    final userMsg = AssistantMessage(
      role: 'user',
      text: text,
      createdAt: DateTime.now(),
    );
    messages.add(userMsg);
    await _persist(userMsg);

    thinking.value = true;
    try {
      final reply = await backend.respond(text, scopeRecordingPath: scopeRecordingPath);
      messages.add(reply);
      await _persist(reply);
    } catch (e) {
      final errMsg = AssistantMessage(
        role: 'assistant',
        text: '出错了：$e',
        createdAt: DateTime.now(),
      );
      messages.add(errMsg);
      await _persist(errMsg);
    } finally {
      thinking.value = false;
    }
  }

  /// 开新会话（清空消息，不删历史）
  Future<void> newSession() async {
    _sessionId = null;
    messages.clear();
  }

  Future<void> _persist(AssistantMessage msg) async {
    final db = _db;
    if (db == null) return;
    try {
      final sid = await _ensureSession();
      await db.insert('chat_messages', {
        'sessionId': sid,
        'role': msg.role,
        'content': msg.text,
        'toolCard': msg.toolCard == null
            ? null
            : jsonEncode({'kind': msg.toolCard!.kind, 'payload': msg.toolCard!.payload}),
        'createdAt': msg.createdAt.millisecondsSinceEpoch,
      });
      await db.update(
        'chat_sessions',
        {'updatedAt': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [sid],
      );
    } catch (e) {
      debugPrint('[AssistantService] 消息入库失败: $e');
    }
  }

  AssistantMessage _rowToMessage(Map<String, Object?> r) {
    AssistantToolCard? card;
    final raw = r['toolCard'] as String?;
    if (raw != null && raw.isNotEmpty) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        card = AssistantToolCard(
          kind: m['kind'] as String,
          payload: (m['payload'] as Map?)?.cast<String, dynamic>() ?? {},
        );
      } catch (_) {}
    }
    return AssistantMessage(
      id: r['id'] as int?,
      role: r['role'] as String,
      text: r['content'] as String? ?? '',
      toolCard: card,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (r['createdAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mock 后端：本地真数据 + 规则应答
// ---------------------------------------------------------------------------

class MockAssistantBackend implements AssistantBackend {
  @override
  Future<AssistantMessage> respond(String text, {String? scopeRecordingPath}) async {
    // 模拟网络/推理延迟，让 thinking 态可感知
    await Future.delayed(const Duration(milliseconds: 600));
    final q = text.toLowerCase();

    // --- 设备状态 ---
    if (q.contains('电量') || q.contains('设备') || q.contains('连接')) {
      return _deviceAnswer();
    }
    // --- 最近录音 ---
    if (q.contains('录音') || q.contains('文件') || q.contains('记录')) {
      return _recordingsAnswer();
    }
    // --- 今日概览 / 总结今天 ---
    if (q.contains('今天') || q.contains('概览') || q.contains('总结') || q.contains('日报')) {
      return _todayAnswer();
    }
    // --- 任务 ---
    if (q.contains('任务') || q.contains('转写') || q.contains('下载') || q.contains('进度')) {
      return _tasksAnswer();
    }

    return AssistantMessage(
      role: 'assistant',
      text: '我还在成长中（当前为本地 Mock 应答）。你可以问我：\n'
          '· 设备电量和连接状态\n'
          '· 最近的录音\n'
          '· 今日概览\n'
          '· 下载 / 转写任务进度',
      createdAt: DateTime.now(),
    );
  }

  AssistantMessage _deviceAnswer() {
    final c = DeviceSessionController.instance;
    final device = c.connectedDevice.value;
    final connected = device != null && c.connectionPhase.value.isUsable;
    final battery = c.battery.value;
    if (!connected) {
      return AssistantMessage(
        role: 'assistant',
        text: '当前没有连接的设备。到「设备」页打开录音笔并扫描连接即可；连接后我可以帮你遥控录音、下载文件。',
        toolCard: const AssistantToolCard(kind: 'device', payload: {'connected': false}),
        createdAt: DateTime.now(),
      );
    }
    return AssistantMessage(
      role: 'assistant',
      text: '${device.name} 已连接${battery != null ? '，电量 ${battery.levelPercent}%${battery.isCharging ? '（充电中）' : ''}' : ''}。',
      toolCard: AssistantToolCard(kind: 'device', payload: {
        'connected': true,
        'name': device.name,
        'battery': battery?.levelPercent,
        'charging': battery?.isCharging ?? false,
      }),
      createdAt: DateTime.now(),
    );
  }

  AssistantMessage _recordingsAnswer() {
    final list = RecordingLibrary.instance.recordings.take(3).toList();
    if (list.isEmpty) {
      return AssistantMessage(
        role: 'assistant',
        text: '本地还没有录音。连接设备后在「设备」页快传文件，或直接开始一段录音。',
        toolCard: const AssistantToolCard(kind: 'recordings', payload: {'count': 0}),
        createdAt: DateTime.now(),
      );
    }
    return AssistantMessage(
      role: 'assistant',
      text: '最近 ${list.length} 条录音：',
      toolCard: AssistantToolCard(kind: 'recordings', payload: {
        'count': RecordingLibrary.instance.recordings.length,
        'items': list
            .map((r) => {
                  'fileName': r.fileName,
                  'sizeLabel': r.sizeLabel,
                  'sourceLabel': r.sourceLabel,
                  'date': '${r.createdAt.month}/${r.createdAt.day}',
                })
            .toList(),
      }),
      createdAt: DateTime.now(),
    );
  }

  AssistantMessage _todayAnswer() {
    final lib = RecordingLibrary.instance;
    final total = lib.recordings.length;
    final today = lib.todayCount.value;
    final device = DeviceSessionController.instance.connectedDevice.value;
    final hour = DateTime.now().hour;
    final period = hour < 11 ? '上午' : (hour < 18 ? '下午' : '晚上');
    return AssistantMessage(
      role: 'assistant',
      text: '$period好。${device != null ? '${device.name} 在线，' : '设备未连接，'}'
          '本地共 $total 条录音（今天 +$today）。'
          '${today > 0 ? '要我把今天的录音整理成纪要或提取待办吗？' : '有新的录音后我可以帮你总结。'}',
      toolCard: AssistantToolCard(kind: 'tasks', payload: {
        'recordings': total,
        'today': today,
        'activeTasks': TaskCenter.instance.activeTasks.length,
      }),
      createdAt: DateTime.now(),
    );
  }

  AssistantMessage _tasksAnswer() {
    final active = TaskCenter.instance.activeTasks;
    if (active.isEmpty) {
      return AssistantMessage(
        role: 'assistant',
        text: '现在没有进行中的任务。转写/生成任务会在后端接通后自动排队（当前 Mock 阶段仅设备下载任务实时可见）。',
        toolCard: const AssistantToolCard(kind: 'tasks', payload: {'activeTasks': 0}),
        createdAt: DateTime.now(),
      );
    }
    return AssistantMessage(
      role: 'assistant',
      text: '进行中的任务：',
      toolCard: AssistantToolCard(kind: 'tasks', payload: {
        'activeTasks': active.length,
        'items': active
            .map((t) => {'title': t.title, 'type': t.typeLabel, 'progress': t.progress})
            .toList(),
      }),
      createdAt: DateTime.now(),
    );
  }
}

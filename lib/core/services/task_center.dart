/// 任务中心：下载 / 导入 / 转写 / 生成 四类任务的统一状态机。
///
/// 数据源双轨：设备侧事件（传输进度、导入完成、固件升级）实时驱动
/// 「进行中」；全部状态落 tasks 表成为流水历史。转写/生成任务由
/// 云端链路（LynseApi 接通后）通过 [submit] 提交，同一状态机管理。
library;

import 'package:dting/core/hardware/hardware_kit.dart';
import 'package:dting/core/services/device_session_controller.dart';
import 'package:dting/utils/local_sqldb.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';

/// 任务类型
enum TaskType { download, importTask, transcribe, summarize, firmware }

/// 任务状态（PRD-02 F2-5 统一轮询状态机同构）
enum TaskStatus { queued, running, success, failed, canceled }

class TaskEntry {
  final int? id;
  final TaskType type;
  final TaskStatus status;
  final int progress; // 0-100
  final String title;
  final String? refId;
  final String? error;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskEntry({
    this.id,
    required this.type,
    this.status = TaskStatus.queued,
    this.progress = 0,
    required this.title,
    this.refId,
    this.error,
    required this.createdAt,
    required this.updatedAt,
  });

  TaskEntry copyWith({
    int? id,
    TaskStatus? status,
    int? progress,
    String? title,
    String? error,
    DateTime? updatedAt,
  }) =>
      TaskEntry(
        id: id ?? this.id,
        type: type,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        title: title ?? this.title,
        refId: refId,
        error: error,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  String get typeLabel => switch (type) {
        TaskType.download => '下载',
        TaskType.importTask => '导入',
        TaskType.transcribe => '转写',
        TaskType.summarize => '生成',
        TaskType.firmware => '固件升级',
      };

  bool get isActive => status == TaskStatus.queued || status == TaskStatus.running;
}

class TaskCenter extends GetxController {
  TaskCenter._();

  static TaskCenter get instance => Get.find<TaskCenter>();

  static TaskCenter init() {
    if (Get.isRegistered<TaskCenter>()) return Get.find<TaskCenter>();
    final c = TaskCenter._();
    Get.put(c, permanent: true);
    return c;
  }

  Database? get _db => SqlDBHelper.database;

  /// 进行中的任务（内存态，事件驱动）
  final activeTasks = <TaskEntry>[].obs;

  /// 历史流水（DB 读取）
  final history = <TaskEntry>[].obs;

  /// 设备侧「当前下载任务」的去重键（同一次快传只产生一条任务）
  int? _deviceDownloadDbId;

  /// shell 启动时调用
  void bootstrap() {
    _loadHistory();
    final session = DeviceSessionController.instance;
    // 传输进度 → 下载任务
    ever<dynamic>(session.transferProgress, (dynamic event) {
      final p = event;
      if (p is! TransferProgress) return;
      _onTransferProgress(p);
    });
    // 文件导入完成 → 导入任务（成功即结束）
    ever<dynamic>(session.lastImported, (dynamic rec) {
      if (rec is! ImportedRecording) return;
      _finishDeviceDownload();
      _record(TaskEntry(
        type: TaskType.importTask,
        status: TaskStatus.success,
        progress: 100,
        title: rec.filePath.split('/').last,
        refId: rec.filePath,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    });
    // 固件升级 → 固件任务
    ever<dynamic>(session.firmwareEvent, (dynamic e) {
      if (e is! FirmwareEvent) return;
      _onFirmware(e);
    });
  }

  // ------------------------------------------------------------------
  // 对外提交口（转写/生成等云端任务接入点，Phase 6+/联调用）
  // ------------------------------------------------------------------

  /// 提交一个新任务，返回可更新的内存句柄下标（用 [update] 推进）。
  Future<TaskEntry> submit(
    TaskType type,
    String title, {
    String? refId,
  }) async {
    final task = TaskEntry(
      type: type,
      status: TaskStatus.running,
      title: title,
      refId: refId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final saved = await _persist(task);
    activeTasks.add(saved);
    return saved;
  }

  /// 推进任务（进度/状态/错误），同步内存与 DB。
  Future<void> advance(
    TaskEntry task, {
    TaskStatus? status,
    int? progress,
    String? error,
  }) async {
    final next = task.copyWith(
      status: status,
      progress: progress,
      error: error,
      updatedAt: DateTime.now(),
    );
    final i = activeTasks.indexWhere((t) => t.id == task.id);
    if (next.isActive) {
      if (i >= 0) activeTasks[i] = next;
    } else {
      if (i >= 0) activeTasks.removeAt(i);
      await _loadHistory();
    }
    await _updateRow(next);
  }

  // ------------------------------------------------------------------
  // 设备事件映射
  // ------------------------------------------------------------------

  void _onTransferProgress(TransferProgress p) {
    switch (p.state) {
      case TransferState.transferring:
        final percent = p.fraction.clamp(0.0, 1.0) * 100;
        if (_deviceDownloadDbId != null) {
          final i = activeTasks.indexWhere((t) => t.id == _deviceDownloadDbId);
          if (i >= 0) {
            activeTasks[i] = activeTasks[i].copyWith(
              progress: percent.round(),
              updatedAt: DateTime.now(),
            );
            _updateRow(activeTasks[i]);
            return;
          }
        }
        // 新起一个下载任务
        final task = TaskEntry(
          type: TaskType.download,
          status: TaskStatus.running,
          progress: percent.round(),
          title: '设备文件快传',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        _persist(task).then((saved) {
          _deviceDownloadDbId = saved.id;
          activeTasks.add(saved);
        });
      case TransferState.completed:
        _finishDeviceDownload();
      case TransferState.failed:
        final i = activeTasks.indexWhere((t) => t.id == _deviceDownloadDbId);
        if (i >= 0) {
          final failed = activeTasks[i].copyWith(
            status: TaskStatus.failed,
            error: '传输中断',
            updatedAt: DateTime.now(),
          );
          activeTasks.removeAt(i);
          _updateRow(failed);
          _loadHistory();
        }
        _deviceDownloadDbId = null;
      case TransferState.cancelled:
        _finishDeviceDownload(status: TaskStatus.canceled);
      case TransferState.idle:
        break;
    }
  }

  void _finishDeviceDownload({TaskStatus status = TaskStatus.success}) {
    final i = activeTasks.indexWhere((t) => t.id == _deviceDownloadDbId);
    if (i >= 0) {
      final done = activeTasks[i].copyWith(
        status: status,
        progress: 100,
        updatedAt: DateTime.now(),
      );
      activeTasks.removeAt(i);
      _updateRow(done);
      _loadHistory();
    }
    _deviceDownloadDbId = null;
  }

  void _onFirmware(FirmwareEvent e) {
    switch (e.state) {
      case FirmwareState.started:
        submit(TaskType.firmware, '固件升级');
      case FirmwareState.progress:
        final i = activeTasks.indexWhere(
          (t) => t.type == TaskType.firmware && t.isActive,
        );
        if (i >= 0) {
          activeTasks[i] = activeTasks[i].copyWith(
            progress: e.progressPercent.clamp(0, 100),
            updatedAt: DateTime.now(),
          );
          _updateRow(activeTasks[i]);
        }
      case FirmwareState.success:
        _finishByType(TaskType.firmware);
      case FirmwareState.failed:
        _finishByType(TaskType.firmware, status: TaskStatus.failed, error: '固件升级失败');
      case FirmwareState.idle:
        break;
    }
  }

  void _finishByType(TaskType type, {TaskStatus status = TaskStatus.success, String? error}) {
    final i = activeTasks.indexWhere((t) => t.type == type && t.isActive);
    if (i >= 0) {
      final done = activeTasks[i].copyWith(
        status: status,
        error: error,
        progress: status == TaskStatus.success ? 100 : null,
        updatedAt: DateTime.now(),
      );
      activeTasks.removeAt(i);
      _updateRow(done);
      _loadHistory();
    }
  }

  // ------------------------------------------------------------------
  // 持久化
  // ------------------------------------------------------------------

  Future<TaskEntry> _persist(TaskEntry task) async {
    final db = _db;
    if (db == null) return task;
    try {
      final id = await db.insert('tasks', {
        'type': task.type.name,
        'status': task.status.name,
        'progress': task.progress,
        'title': task.title,
        'refId': task.refId,
        'error': task.error,
        'createdAt': task.createdAt.millisecondsSinceEpoch,
        'updatedAt': task.updatedAt.millisecondsSinceEpoch,
      });
      return task.copyWith(id: id);
    } catch (e) {
      debugPrint('[TaskCenter] 任务入库失败: $e');
      return task;
    }
  }

  Future<void> _updateRow(TaskEntry task) async {
    final db = _db;
    if (db == null || task.id == null) return;
    try {
      await db.update(
        'tasks',
        {
          'status': task.status.name,
          'progress': task.progress,
          'error': task.error,
          'updatedAt': task.updatedAt.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [task.id],
      );
    } catch (e) {
      debugPrint('[TaskCenter] 任务更新失败: $e');
    }
  }

  Future<void> _record(TaskEntry task) async {
    await _persist(task);
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = _db;
    if (db == null) return;
    try {
      final rows = await db.query(
        'tasks',
        where: "status IN ('success','failed','canceled')",
        orderBy: 'updatedAt DESC',
        limit: 50,
      );
      history.assignAll(rows.map((r) {
        return TaskEntry(
          id: r['id'] as int?,
          type: TaskType.values.firstWhere(
            (t) => t.name == r['type'],
            orElse: () => TaskType.download,
          ),
          status: TaskStatus.values.firstWhere(
            (s) => s.name == r['status'],
            orElse: () => TaskStatus.success,
          ),
          progress: (r['progress'] as num?)?.toInt() ?? 0,
          title: (r['title'] as String?) ?? '',
          refId: r['refId'] as String?,
          error: r['error'] as String?,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            (r['createdAt'] as num?)?.toInt() ?? 0,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (r['updatedAt'] as num?)?.toInt() ?? 0,
          ),
        );
      }));
    } catch (e) {
      debugPrint('[TaskCenter] 历史读取失败: $e');
    }
  }

  /// 清空历史（设置页入口）
  Future<void> clearHistory() async {
    final db = _db;
    if (db == null) return;
    await db.delete('tasks', where: "status IN ('success','failed','canceled')");
    await _loadHistory();
  }
}

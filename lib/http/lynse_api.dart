/// Lynse 后端 API client（按 lynse-desktop 契约实现）。
///
/// 覆盖前端基本闭环所需端点：
/// 文件上传（预签名直传）→ 转写任务（提交/轮询/拉取）→ 转写编辑
/// → 模板纪要（conclusion / outline / todo）→ 导出 → OTA。
///
/// 契约参考：
/// - lynse-desktop/packages/views/workspace/hooks/use-files.ts（调用侧）
/// - lynse-desktop/skills/lynse-cli/lynse-cli-b/docs/*.md（DTO 定义）
///
/// 数据解析直接用 Map（不做 json 代码生成），字段访问集中在本文件，
/// 契约有出入时只改这一层。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dting/config/lynse_backend.dart';
import 'package:dting/utils/local_database.dart';

class LynseApiException implements Exception {
  final int code;
  final String message;

  LynseApiException(this.code, this.message);

  @override
  String toString() => 'LynseApiException($code, $message)';
}

/// 转写 segment（对应 FileTransRecordVO / LocalTranscriptionSegment）
class TransSegment {
  final String id;
  final int? beginTimeMs;
  final int? endTimeMs;
  final String? beginTimeStr;
  final String? endTimeStr;
  final String? speakerId;
  final String? speakerName;
  final String text;

  const TransSegment({
    required this.id,
    this.beginTimeMs,
    this.endTimeMs,
    this.beginTimeStr,
    this.endTimeStr,
    this.speakerId,
    this.speakerName,
    required this.text,
  });

  factory TransSegment.fromMap(Map<String, dynamic> m) {
    int? ms(dynamic v) => v == null ? null : int.tryParse('$v');
    return TransSegment(
      id: '${m['id'] ?? m['recordId'] ?? ''}',
      beginTimeMs: ms(m['beginTime'] ?? m['startMs']),
      endTimeMs: ms(m['endTime'] ?? m['endMs']),
      beginTimeStr: m['beginTimeStr']?.toString(),
      endTimeStr: m['endTimeStr']?.toString(),
      speakerId: m['speakerId']?.toString(),
      speakerName: m['speakerName']?.toString(),
      text: m['text']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toEditPatch() => {
        'recordId': id,
        if (text.isNotEmpty) 'text': text,
        if (speakerId != null) 'speakerId': speakerId,
        if (speakerName != null) 'speakerName': speakerName,
        if (endTimeMs != null) 'endTime': endTimeMs,
      };
}

/// 纪要总结（FileConclusion）
class Conclusion {
  final String id;
  final String fileId;
  final String templateId;
  final String templateName;
  final String text;

  /// md | html
  final String contentFormat;
  final int version;

  const Conclusion({
    required this.id,
    required this.fileId,
    this.templateId = '',
    this.templateName = '',
    required this.text,
    this.contentFormat = 'md',
    this.version = 0,
  });

  factory Conclusion.fromMap(Map<String, dynamic> m) => Conclusion(
        id: '${m['id'] ?? ''}',
        fileId: '${m['fileId'] ?? ''}',
        templateId: '${m['templateId'] ?? ''}',
        templateName: '${m['templateName'] ?? ''}',
        text: m['conclusionText']?.toString() ?? '',
        contentFormat: m['contentFormat']?.toString() ?? 'md',
        version: (m['version'] as num?)?.toInt() ?? 0,
      );
}

/// 大纲（FileOutline）
class Outline {
  final String id;
  final String fileId;
  final String text;
  final String contentFormat;

  const Outline({
    required this.id,
    required this.fileId,
    required this.text,
    this.contentFormat = 'md',
  });

  factory Outline.fromMap(Map<String, dynamic> m) => Outline(
        id: '${m['id'] ?? ''}',
        fileId: '${m['fileId'] ?? ''}',
        text: m['outlineText']?.toString() ?? '',
        contentFormat: m['contentFormat']?.toString() ?? 'md',
      );
}

/// 行动项（FileTodo）
class ActionTodo {
  final String id;
  final String fileId;
  final String content;
  final bool completed;
  final String? owner;
  final String? expectedCompleteTime;

  const ActionTodo({
    required this.id,
    required this.fileId,
    required this.content,
    this.completed = false,
    this.owner,
    this.expectedCompleteTime,
  });

  factory ActionTodo.fromMap(Map<String, dynamic> m) => ActionTodo(
        id: '${m['id'] ?? ''}',
        fileId: '${m['fileId'] ?? ''}',
        content: m['todoContent']?.toString() ?? '',
        completed: m['isCompleted'] == true || '${m['isCompleted']}' == '1',
        owner: m['owner']?.toString(),
        expectedCompleteTime: m['expectedCompleteTime']?.toString(),
      );
}

/// 纪要模板（PromptTemplateItemVO）
class PromptTemplate {
  final String id;
  final String name;
  final String category;
  final bool isDefault;

  /// md | html
  final String contentFormat;

  const PromptTemplate({
    required this.id,
    required this.name,
    this.category = '',
    this.isDefault = false,
    this.contentFormat = 'md',
  });

  factory PromptTemplate.fromMap(Map<String, dynamic> m) => PromptTemplate(
        id: '${m['id'] ?? ''}',
        name: '${m['name'] ?? m['alias'] ?? ''}',
        category: '${m['category'] ?? ''}',
        isDefault: m['isDefault'] == true,
        contentFormat: m['contentFormat']?.toString() ?? 'md',
      );
}

class LynseApi {
  LynseApi._();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: LynseBackend.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
    contentType: Headers.jsonContentType,
  ));

  static void setToken(String? token) {
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = token;
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  /// 启动时从本地缓存恢复登录态
  static void restoreToken() {
    final saved = LocalDataBase().basicBox!.get('lynse_token');
    if (saved is String && saved.isNotEmpty) {
      setToken(saved);
    }
  }

  /// 统一 envelope 解包；非成功码抛 [LynseApiException]
  static Future<dynamic> _request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    final Response response;
    try {
      response = await _dio.request(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method),
      );
    } on DioException catch (e) {
      throw LynseApiException(-1, '网络错误: ${e.message}');
    }
    final body = response.data;
    if (body is! Map) {
      return body;
    }
    final code = (body['code'] as num?)?.toInt() ?? -1;
    if (code != LynseBackend.successCode) {
      throw LynseApiException(code, body['msg']?.toString() ?? '请求失败');
    }
    return body['data'];
  }

  static Future<dynamic> _get(String path,
          {Map<String, dynamic>? query}) =>
      _request('GET', path, query: query);

  static Future<dynamic> _post(String path, {Object? data}) =>
      _request('POST', path, data: data);

  static Future<dynamic> _put(String path, {Object? data}) =>
      _request('PUT', path, data: data);

  static Future<dynamic> _delete(String path) => _request('DELETE', path);

  // ==================================================================
  // 文件上传：预签名直传（PreUploadReq → PreSignedUrlVO）
  // ==================================================================

  /// 申请预签名并直传对象存储，返回 fileId。
  /// [mode]: MEETING | CALL | IMPORT
  static Future<String> uploadRecording({
    required File file,
    required String mode,
    required Duration duration,
    DateTime? recordStartTime,
    String contentType = 'audio/mpeg',
    void Function(double progress)? onProgress,
  }) async {
    final data = await _post('/api/business/file/presign/upload', data: {
      'saveFilename':
          file.path.split(Platform.pathSeparator).last,
      'contentType': contentType,
      'fileSize': file.lengthSync(),
      'mode': mode,
      'bizDuration': duration.inSeconds,
      if (recordStartTime != null)
        'recordStartTime': recordStartTime.millisecondsSinceEpoch ~/ 1000,
    });
    final url = data['url']?.toString() ?? '';
    final fileId = data['fileId']?.toString() ?? '';
    if (url.isEmpty || fileId.isEmpty) {
      throw LynseApiException(-1, '预签名返回不完整');
    }
    final headers = <String, dynamic>{};
    if (data['headers'] is Map) {
      (data['headers'] as Map).forEach((k, v) => headers['$k'] = '$v');
    }
    final dio = Dio();
    await dio.put(
      url,
      data: file.openRead(),
      options: Options(
        headers: headers,
        contentType: contentType,
      ),
      onSendProgress: (sent, total) {
        if (onProgress != null && total > 0) {
          onProgress(sent / total);
        }
      },
    );
    await _get('/api/business/file/upload/notify',
        query: {'fileId': fileId});
    return fileId;
  }

  // ==================================================================
  // 转写：提交 / 轮询 / 拉取
  // ==================================================================

  /// 触发转写（可带纪要模板），返回 taskId
  static Future<String> startTranscription(String fileId,
      {String? templateId}) async {
    final data = await _post('/api/business/file/trans', data: {
      'fileId': fileId,
      if (templateId != null) 'templateId': templateId,
    });
    return '${data['taskId'] ?? ''}';
  }

  /// 轮询转写状态；完成返回 true，失败抛异常
  static Future<bool> transcriptionDone(String fileId) async {
    final data = await _post('/api/business/file/trans/status',
        data: {'fileIds': [fileId]});
    if (data is Map) {
      final status = data[fileId]?['status']?.toString().toLowerCase() ?? '';
      if (['failed', 'error'].contains(status)) {
        throw LynseApiException(-1, '转写失败');
      }
      return ['completed', 'complete', 'success', 'done', '1'].contains(status);
    }
    return false;
  }

  /// 拉取转写结果 segments
  static Future<List<TransSegment>> fetchTranscription(String fileId) async {
    final data = await _get('/api/business/file/trans/get',
        query: {'fileId': fileId});
    List list = const [];
    if (data is Map) {
      // 兼容 records/list/data/segments 多种键（对齐桌面端解析逻辑）
      for (final key in ['records', 'list', 'data', 'segments']) {
        if (data[key] is List) {
          list = data[key] as List;
          break;
        }
      }
    } else if (data is List) {
      list = data;
    }
    return list
        .whereType<Map>()
        .map((m) => TransSegment.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  // ==================================================================
  // 转写编辑
  // ==================================================================

  /// 批量修改 segment（文本/说话人/时间）
  static Future<void> editSegments(List<TransSegment> segments) async {
    await _put('/api/business/file/trans/edit',
        data: segments.map((s) => s.toEditPatch()).toList());
  }

  /// 按 task 全局修改说话人名：[{speakerId, speakerName}]
  static Future<void> renameSpeakers(
      String taskId, List<Map<String, String>> speakerInfoList) async {
    await _put('/api/business/file/trans/speaker', data: {
      'taskId': taskId,
      'speakerInfoList': speakerInfoList,
    });
  }

  // ==================================================================
  // 纪要：模板 / 任务 / 总结 / 大纲 / 行动项
  // ==================================================================

  static Future<List<PromptTemplate>> promptTemplates() async {
    final data = await _get('/api/business/translate/prompt/categories');
    final list = data is List ? data : (data?['list'] as List? ?? const []);
    return list
        .whereType<Map>()
        .map((m) => PromptTemplate.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// 提交纪要生成任务（aiTaskType=CONCLUSION）
  static Future<String> startSummary(String fileId, String templateId) async {
    final data = await _post('/api/business/file/ai', data: {
      'aiTaskType': 'CONCLUSION',
      'fileId': fileId,
      'templateId': templateId,
    });
    return '${data['taskId'] ?? data?['task_id'] ?? ''}';
  }

  /// 轮询 AI 任务结果；status 为完成态时返回 true
  static Future<bool> aiTaskDone(String fileId, String taskId) async {
    final data = await _post('/api/business/file/ai/result', data: {
      'fileId': fileId,
      'taskId': taskId,
      'aiTaskType': 'CONCLUSION',
    });
    final status = data?['status']?.toString().toLowerCase() ?? '';
    if (['failed', 'error'].contains(status)) {
      throw LynseApiException(-1, '纪要生成失败');
    }
    return ['completed', 'complete', 'success', 'done', '1'].contains(status);
  }

  static Future<List<Conclusion>> conclusions(String fileId) async {
    final data = await _get('/api/business/file/conclusion/list',
        query: {'fileId': fileId});
    final list = data is List ? data : const [];
    return list
        .whereType<Map>()
        .map((m) => Conclusion.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// 编辑总结（乐观锁 version）
  static Future<void> editConclusion(
      String conclusionId, String text, int version) async {
    await _put('/api/business/file/conclusion/$conclusionId',
        data: {'conclusionText': text, 'version': version});
  }

  static Future<void> deleteConclusion(String conclusionId) async {
    await _delete('/api/business/file/conclusion/$conclusionId');
  }

  static Future<Outline?> outline(String fileId) async {
    final data = await _get('/api/business/file/outline/get',
        query: {'fileId': fileId});
    if (data is! Map || '${data['id'] ?? ''}'.isEmpty) return null;
    return Outline.fromMap(Map<String, dynamic>.from(data));
  }

  static Future<void> editOutline(String outlineId, String text) async {
    await _put('/api/business/file/outline/$outlineId',
        data: {'outlineText': text});
  }

  static Future<List<ActionTodo>> todos(String fileId) async {
    final data = await _get('/api/business/file/todo/list',
        query: {'fileId': fileId});
    final list = data is List ? data : const [];
    return list
        .whereType<Map>()
        .map((m) => ActionTodo.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  static Future<void> updateTodo(String todoId,
      {bool? completed, String? content}) async {
    await _put('/api/business/file/todo/$todoId', data: {
      if (completed != null) 'isCompleted': completed,
      if (content != null) 'todoContent': content,
    });
  }

  // ==================================================================
  // 文件管理
  // ==================================================================

  static Future<void> renameFile(String fileId, String newName) async {
    await _put('/api/business/file/$fileId',
        data: {'newOriginalFilename': newName});
  }

  static Future<void> deleteFiles(List<String> fileIds) async {
    await _request('DELETE', '/api/business/file/delete',
        query: {'fileIds': fileIds.join(',')});
  }

  // ==================================================================
  // 导出（exportType: md / txt / srt，具体枚举以联调为准）
  // ==================================================================

  /// 导出转写/纪要文本，返回内容字符串
  static Future<String> exportText(
      {required String fileId,
      required String kind,
      required String exportType}) async {
    final path = kind == 'outline'
        ? '/api/business/file/outline/export'
        : '/api/business/file/trans/export';
    final response = await _dio.get(path, queryParameters: {
      'fileId': fileId,
      'exportType': exportType,
    }, options: Options(responseType: ResponseType.plain));
    return response.data?.toString() ?? '';
  }
}

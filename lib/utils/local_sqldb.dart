import 'package:sqflite/sqflite.dart';
import 'package:dting/model/file_model/file_management_model/upload_file_model.dart';

class SqlDBHelper {
  static Database? _database;
  static final SqlDBHelper _instance = SqlDBHelper._();
  factory SqlDBHelper() => _instance;
  SqlDBHelper._();

  /// 助手版数据层（lib/core/data/）共用的数据库句柄（initDb 之后可用）
  static Database? get database => _database;

  Future<bool> initDb() async {
    if (_database != null) {
      _database;
    } else {
      final dbPath = await getDatabasesPath();
      final path = "$dbPath/dting.db";
      _database = await openDatabase(
        path,
        version: 3,
        onCreate: _createDb,
        onUpgrade: _upgradeDb,
      );
    }
    return true;
  }

  /// 助手版数据层的建表语句（v3）：录音索引 / 任务流水 / 会话 / 消息 / 行动项。
  /// 独立成方法供 onCreate 与 onUpgrade 复用。
  Future _createAssistantTables(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS recordings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      filePath TEXT NOT NULL UNIQUE,
      fileName TEXT NOT NULL,
      ext TEXT,
      fileSize INTEGER NOT NULL DEFAULT 0,
      durationMs INTEGER,
      source TEXT NOT NULL,
      vendorId TEXT,
      deviceName TEXT,
      transStatus TEXT NOT NULL DEFAULT 'none',
      cloudFileId TEXT,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL
    )
    ''');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      status TEXT NOT NULL,
      progress INTEGER NOT NULL DEFAULT 0,
      title TEXT,
      refId TEXT,
      payload TEXT,
      error TEXT,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL
    )
    ''');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS chat_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      scope TEXT NOT NULL DEFAULT 'global',
      recordingId INTEGER,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL
    )
    ''');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS chat_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sessionId INTEGER NOT NULL,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      toolCard TEXT,
      createdAt INTEGER NOT NULL
    )
    ''');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS action_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      recordingId INTEGER,
      content TEXT NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0,
      dueDate TEXT,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL
    )
    ''');
  }

  Future _createDb(Database db, int version) async {
    try {
      await db.execute('''
    CREATE TABLE dting_voice (
      fileId VARCHAR(100) NOT NULL,
      httpVoiceUrl VARCHAR(500) NOT NULL,
      localVoiceUrl VARCHAR(500) NOT NULL
    )
     ''');

      // 创建待上传文件表
      await db.execute('''
    CREATE TABLE upload_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customerId VARCHAR(100),
      teamId VARCHAR(100),
      folderId VARCHAR(100),
      path VARCHAR(500) NOT NULL,
      macAddress VARCHAR(100),
      location VARCHAR(500),
      saveFilename VARCHAR(200) NOT NULL,
      objectId VARCHAR(100),
      bizDuration INTEGER NOT NULL,
      mode VARCHAR(50) NOT NULL,
      fileSize INTEGER NOT NULL,
      recordStartTime VARCHAR(100),
      uploadStatus INTEGER DEFAULT 0,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      retryCount INTEGER DEFAULT 0,
       scene INTEGER NOT NULL,
      errorMessage TEXT
    )
     ''');

      await _createAssistantTables(db);
    } catch (e) {
      print('Error: $e');
    }
  }

  Future _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
    CREATE TABLE upload_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customerId VARCHAR(100),
      teamId VARCHAR(100),
      folderId VARCHAR(100),
      path VARCHAR(500) NOT NULL,
      macAddress VARCHAR(100),
      location VARCHAR(500),
      saveFilename VARCHAR(200) NOT NULL,
      objectId VARCHAR(100),
      bizDuration INTEGER NOT NULL,
      mode VARCHAR(50) NOT NULL,
      fileSize INTEGER NOT NULL,
      recordStartTime VARCHAR(100),
      uploadStatus INTEGER DEFAULT 0,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      retryCount INTEGER DEFAULT 0,
      scene INTEGER NOT NULL,
      errorMessage TEXT
    )
     ''');
    }
    if (oldVersion < 3) {
      // 助手版数据层五表（IF NOT EXISTS，升级/新建路径安全复用）
      await _createAssistantTables(db);
    }
  }

  static void insertRead({
    required String fildId,
    required String httpVoiceUrl,
    required String localVoiceUrl,
  }) async {
    await _database!.insert('dting_voice', {
      'fileId': fildId,
      'httpVoiceUrl': httpVoiceUrl,
      'localVoiceUrl': localVoiceUrl,
    });
  }

  // static void insertReading({required String fildId}) async {
  //   await _database!.insert('dting_reading', {
  //     'fileId': fildId,
  //   }, conflictAlgorithm: ConflictAlgorithm.replace);
  // }

  // 移除本地化数据的方法
  Future<void> removeLocalization(String key) async {
    await _database!.delete(
      "dting_voice",
      where: 'fileId = ?',
      whereArgs: [key],
    );
  }

  static Future<List<Map<String, dynamic>>> hasLocalization(String key) async {
    List<Map<String, dynamic>> result = await _database!.query(
      "dting_voice",
      where: 'fileId = ?',
      whereArgs: [key],
    );
    return result;
  }

  static Future<void> clearDatabase() async {
    // 清除数据表
    await _database!.delete('dting_voice');
  }

  static Future<void> updateData({
    required String fildId,
    required String updateLocalUrl,
  }) async {
    await _database!.update(
      'dting_voice',
      {'localVoiceUrl': updateLocalUrl},
      where: 'fileId = ?',
      whereArgs: [fildId],
    );
  }

  static Future<void> updateAIData({
    required String fildId,
    required String updatefileType,
    required String content,
  }) async {
    await _database!.execute(
      'UPDATE dting_voice SET $updatefileType = $content WHERE fildId = $fildId',
    );
  }

  Future<void> deleteData(Database db, int id) async {
    await db.delete('dting_voice', where: 'fildId = ?', whereArgs: [id]);
  }

  // 待上传文件相关方法
  static Future<void> insertUploadQueue(UploadFileModel uploadFile) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database!.insert('upload_queue', {
      'customerId': uploadFile.customerId,
      'teamId': uploadFile.teamId,
      'folderId': uploadFile.folderId,
      'path': uploadFile.path,
      'macAddress': uploadFile.macAddress,
      'location': uploadFile.location,
      'saveFilename': uploadFile.saveFilename,
      'objectId': uploadFile.objectId,
      'bizDuration': uploadFile.bizDuration,
      'mode': uploadFile.mode,
      'fileSize': uploadFile.fileSize,
      'recordStartTime': uploadFile.recordStartTime,
      'uploadStatus': 0, // 0: 待上传, 1: 上传中, 2: 上传成功, 3: 上传失败
      'createdAt': now,
      'updatedAt': now,
      'retryCount': 0,
      'scene': uploadFile.scene,
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingUploads() async {
    return await _database!.query(
      'upload_queue',
      where: 'uploadStatus IN (0, 3)', // 待上传或上传失败的文件
      orderBy: 'createdAt ASC',
    );
  }

  static Future<void> updateUploadStatus(
    int id,
    int status, {
    String? errorMessage,
  }) async {
    final updateData = {
      'uploadStatus': status,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    // if (errorMessage != null) {
    //   updateData['errorMessage'] = errorMessage.toString();
    // }

    if (status == 3) {
      // 上传失败时增加重试次数
      // 使用 rawUpdate 来执行 SQL 表达式
      await _database!.rawUpdate(
        'UPDATE upload_queue SET uploadStatus = ?, updatedAt = ?, retryCount = retryCount + 1${errorMessage != null ? ', errorMessage = ?' : ''} WHERE id = ?',
        errorMessage != null
            ? [status, DateTime.now().millisecondsSinceEpoch, errorMessage, id]
            : [status, DateTime.now().millisecondsSinceEpoch, id],
      );
    } else {
      await _database!.update(
        'upload_queue',
        updateData,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  static Future<void> removeUploadedFile(int id) async {
    await _database!.delete('upload_queue', where: 'id = ?', whereArgs: [id]);
  }

  // static Future<List<Map<String, dynamic>>> getDisplayUploadQueue(
  //   String? teamId,
  // ) async {
  //   return await _database!.query(
  //     'upload_queue',
  //     where: 'uploadStatus IN (0, 1, 3) and teamId=$teamId', // 待上传、上传中、上传失败
  //     orderBy: 'createdAt DESC',
  //   );
  // }
  static Future<List<Map<String, dynamic>>> getDisplayUploadQueue({
    String? teamId,
  }) async {
    String whereClause = 'uploadStatus IN (0, 1, 3)'; // 待上传、上传中、上传失败
    List<dynamic> whereArgs = [];

    if (teamId != null) {
      whereClause += ' AND teamId = ?';
      whereArgs.add(teamId);
    } else {
      whereClause += ' AND teamId IS NULL';
    }

    return await _database!.query(
      'upload_queue',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'createdAt DESC',
    );
  }
  
  // 重置所有上传中状态的文件为上传失败
  static Future<int> resetUploadingStatus() async {
    if (_database == null) {
      print('数据库未初始化');
      return 0;
    }
    
    // 查询所有状态为上传中的记录
    final uploadingFiles = await _database!.query(
      'upload_queue',
      where: 'uploadStatus = ?',
      whereArgs: [1], // 上传中状态
    );
    
    print('发现 ${uploadingFiles.length} 个上传中断的文件，将重置为上传失败状态');
    
    // 将所有上传中的记录更新为上传失败
    for (final file in uploadingFiles) {
      final id = file['id'] as int;
      await updateUploadStatus(
        id,
        3, // 上传失败状态
        errorMessage: '应用重启，上传中断',
      );
    }
    
    return uploadingFiles.length;
  }
}

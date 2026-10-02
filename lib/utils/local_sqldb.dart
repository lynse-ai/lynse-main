/// 助手版本地数据库（dting.db）。
///
/// v3 起 schema 由助手版数据层拥有：recordings / tasks / chat_sessions /
/// chat_messages / action_items 五张表。旧表（dting_voice / upload_queue）
/// 保留在库中不迁移数据，但代码面不再使用。
library;

import 'package:sqflite/sqflite.dart';

class SqlDBHelper {
  static Database? _database;
  static final SqlDBHelper _instance = SqlDBHelper._();
  factory SqlDBHelper() => _instance;
  SqlDBHelper._();

  /// 助手版数据层（lib/core/data/）共用的数据库句柄（initDb 之后可用）
  static Database? get database => _database;

  Future<bool> initDb() async {
    if (_database == null) {
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
    // 旧表建表保留（新装用户无历史数据，但避免任何旧查询路径崩溃）
    await db.execute('''
    CREATE TABLE IF NOT EXISTS dting_voice (
      fileId VARCHAR(100) NOT NULL,
      httpVoiceUrl VARCHAR(500) NOT NULL,
      localVoiceUrl VARCHAR(500) NOT NULL
    )
    ''');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS upload_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      path VARCHAR(500) NOT NULL,
      saveFilename VARCHAR(200) NOT NULL,
      uploadStatus INTEGER DEFAULT 0,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      retryCount INTEGER DEFAULT 0,
      errorMessage TEXT
    )
    ''');
    await _createAssistantTables(db);
  }

  Future _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // 助手版数据层五表（IF NOT EXISTS，升级/新建路径安全复用）
      await _createAssistantTables(db);
    }
  }
}

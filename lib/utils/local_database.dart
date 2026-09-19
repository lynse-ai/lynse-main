import 'package:hive/hive.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalDataBase {
  static const String _dbPathName = 'hive';
  static const String _basicBoxName = 'basicBox';

  static final LocalDataBase _instance = LocalDataBase._();
  factory LocalDataBase() => _instance;

  Box? basicBox;

  LocalDataBase._();

  Future<bool> init() async {
    await _tryToInitialize();
    await _openBasicBox();

    return true;
  }

  Future<bool> _tryToInitialize() async {
    // check if hive folder is exists
    var rootPath = await getApplicationDocumentsDirectory();
    var hivePath = Directory('${rootPath.path}/$_dbPathName/');
    if (!hivePath.existsSync()) {
      hivePath.createSync();
    }

    Hive.init(hivePath.path);

    // Hive.registerAdapter(WorkOrderApiModelAdapter());

    return true;
  }

  Future<bool> _openBasicBox() async {
    if (!Hive.isBoxOpen(_basicBoxName)) {
      basicBox = await Hive.openBox(_basicBoxName);
    } else {
      basicBox = Hive.box(_basicBoxName);
    }

    return true;
  }

  static cleatCache() async {
    try {
      LocalDataBase().basicBox!.put("language", null);
      LocalDataBase().basicBox!.put("lastLoginPhone", null);
      LocalDataBase().basicBox!.put("lastLoginTime", null);
      LocalDataBase().basicBox!.put("loginUserID", null);
      LocalDataBase().basicBox!.put("loginPwd", null);
      LocalDataBase().basicBox!.put("token", null);
      LocalDataBase().basicBox!.put("islogin", null);
      LocalDataBase().basicBox!.put("wexinCode", null);
      LocalDataBase().basicBox!.put("authType", null);
      LocalDataBase().basicBox!.put("appleToken", null);
      LocalDataBase().basicBox!.put("currentTeamId", null);
    } catch (e) {
      print("Error clearing cache: $e");
    }
  }

  //本地缓存
  static setCache({
    String? language,
    String? lastLoginPhone,
    String? lastLoginTime,
    String? loginUserID,
    String? loginPwd,
    String? wexinCode,
    String? authType,
    String? appleToken,
    String? token,
    String? islogin,
    String? currentTeamId,
  }) {
    if (currentTeamId != null) {
      LocalDataBase().basicBox!.put("currentTeamId", currentTeamId);
    }
    if (language != null) {
      LocalDataBase().basicBox!.put("language", language);
    }
    if (lastLoginPhone != null) {
      LocalDataBase().basicBox!.put("lastLoginPhone", lastLoginPhone);
    }

    if (lastLoginTime != null) {
      LocalDataBase().basicBox!.put("lastLoginTime", lastLoginTime);
    }
    if (loginUserID != null) {
      LocalDataBase().basicBox!.put("loginUserID", loginUserID);
    }
    if (loginPwd != null) {
      LocalDataBase().basicBox!.put("loginPwd", loginPwd);
    }
    if (token != null) {
      LocalDataBase().basicBox!.put("token", token);
    }
    if (islogin != null) {
      LocalDataBase().basicBox!.put("islogin", islogin);
    }
    if (wexinCode != null) {
      LocalDataBase().basicBox!.put("wexinCode", wexinCode);
    }
    if (authType != null) {
      LocalDataBase().basicBox!.put("authType", authType);
    }
    if (appleToken != null) {
      LocalDataBase().basicBox!.put("appleToken", appleToken);
    }
  }
}

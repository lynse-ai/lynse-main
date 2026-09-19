import 'package:get/get.dart';
import 'messages_en.dart' as messages_en;
import 'messages_zh_HK.dart' as messages_zh_hk;
import 'messages_zh_CN.dart' as messages_zh_cn;

class Messages extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en': messages_en.en,
    'zh_CN': messages_zh_cn.zhCN,
    'zh_HK': messages_zh_hk.zhHK,
  };
}

/// 助手版路由：唯一入口为助手外壳（无账号纯本地，第一版）。
library;

import 'package:dting/router/modules/assistant_router.dart';

class AppRouter {
  static final initialRoute = AssistantRouter.shell;

  static final pages = [
    ...AssistantRouter.pages,
  ];
}

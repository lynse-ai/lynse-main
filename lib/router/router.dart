import 'package:dting/router/modules/device_router.dart';
import 'package:dting/router/modules/home_router.dart';
import 'package:dting/router/modules/login_router.dart';
import 'package:dting/router/modules/lynse_router.dart';
import 'package:dting/router/modules/payment_router.dart';
import 'package:dting/router/modules/personal_router.dart';
import 'package:dting/router/modules/team_router.dart';
import 'package:dting/router/modules/translate_router.dart';

class AppRouter {
  static final initialRoute = LoginRouter.starup;
  // static final initialRoute = LoginRouter.test;

  static final pages = [
    ...LoginRouter.pages,
    ...HomeRouter.pages,
    ...PersonalRouter.pages,
    ...ManageDeviceRouter.pages,
    ...TeamRouter.pages,
    ...PaymentRouter.pages,
    ...TranslateRouter.pages,
    ...LynseRouter.pages,
  ];
}

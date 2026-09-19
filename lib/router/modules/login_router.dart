import 'package:dting/pages/login/areement/areement_binging.dart';
import 'package:dting/pages/login/areement/areement_page.dart';
import 'package:dting/pages/login/setbindpassword/bindmobilephone_setpwd_binding.dart';
import 'package:dting/pages/login/setbindpassword/bindmobilephone_setpwd_page.dart';
import 'package:get/get.dart';

import 'package:dting/pages/login/bindmobilephone/bindmobilephone_binding.dart';
import 'package:dting/pages/login/bindmobilephone/bindmobilephone_page.dart';
import 'package:dting/pages/login/forgotpassword/forgotpassword_binging.dart';
import 'package:dting/pages/login/forgotpassword/forgotpassword_page.dart';
import 'package:dting/pages/login/mobilelogin/mobilelogin_binding.dart';
import 'package:dting/pages/login/mobilelogin/mobilelogin_page.dart';
import 'package:dting/pages/login/starup/starup_binding.dart';
import 'package:dting/pages/login/starup/starup_page.dart';

class LoginRouter {
  static final test = '/test';
  static final starup = '/startup';
  static final agreement = '/agreement';
  static final forgotpassword = '/forgotpassword';
  static final mobilelogin = '/mobilelogin';
  static final bindmobilephone = '/bindmobilephone';
  static final bindmobilephonewithsetpwd = '/bindmobilephonewithsetpwd';
  static final phoneCodeLogin = '/phoneCodeLogin';

  static final pages = [
    GetPage(
      name: agreement,
      page: () => AreementPage(),
      binding: AreementBinging(),
    ),

    GetPage(
      name: starup,
      page: () => const StarupPage(),
      binding: StarupBinding(),
    ),
    GetPage(
      name: forgotpassword,
      page: () => const ForgotpasswordPage(),
      binding: ForgotpasswordBinging(),
    ),

    GetPage(
      name: mobilelogin,
      page: () => const MobileLogInPage(),
      binding: MobileLogInBinding(),
    ),
    // GetPage(
    //   name: phoneCodeLogin,
    //   page: () => const PhoneCodeLoginPage(),
    //   binding: MobileLogInBinding(),
    // ),
    GetPage(
      name: bindmobilephone,
      page: () => const BindMobilePhonePage(),
      binding: BindMobilePhoneBinding(),
    ),

    GetPage(
      name: bindmobilephonewithsetpwd,
      page: () => const SetPwdForBindMobilePhonePage(),
      binding: SetPwdForBindMobilePhoneBinding(),
    ),
  ];
}

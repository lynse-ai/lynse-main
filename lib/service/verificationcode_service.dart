import 'package:dting/model/baseapi/response_api_model.dart';
import 'package:dting/model/verificationcode/verificationcode_email_model.dart';
import 'package:dting/model/verificationcode/verificationcode_sms_model.dart';

import '../http/http_helper.dart';

class VerificationCodeService {
  VerificationCodeService._();
 
  //邮箱验证
  static Future<bool> getCodeByEmail(VerificationCodeByEmailModel email) async {
    bool returnData = false;

    await HttpHelper.get(
      '/api/auth/captcha/email',
      queryParameters: {"email": email.email, "actionType": email.actionType},
    ).then((value) {
      if (value?.code == 200) {
        returnData = true;
      }
    });

    return returnData;
  }

  //短信验证
  static Future<ResponseApiModel?> getCodeBySMS(
    VerificationCodeBySMSModel sms,
  ) async {
    ResponseApiModel? returnData;

    await HttpHelper.get(
      '/api/auth/captcha/sms',
      queryParameters: {"phone": sms.phone, "actionType": sms.actionType},
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }
}

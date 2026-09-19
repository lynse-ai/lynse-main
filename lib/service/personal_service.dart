import 'package:dting/http/http_helper.dart';
import 'package:dting/model/baseapi/response_api_model.dart';
import 'package:dting/model/personal_model/quota_model.dart';
import 'package:dting/model/personal_model/submit_report_model.dart';
import 'package:dting/model/personal_model/userinfo_model.dart';
import 'package:dting/model/personal_model/vip_package_model.dart';
import 'package:dting/widgets/dialog/dialog.dart';

class PersonalService {
  PersonalService._();

  //VIP 权益 packageType=> 免费/Pro/Max）
  static Future<List<VIPackageModel>> getPriceList({
    String? packageType,
  }) async {
    List<VIPackageModel> returnData = [];

    await HttpHelper.get(
      '/api/pay/price/list',
      queryParameters: {"packageType": packageType},
    ).then((value) {
      if (value != null && value.data != null) {
        returnData = List<VIPackageModel>.from(
          value.data.map((x) => VIPackageModel.fromJson(x)),
        );
      }
    });
    return returnData;
  }

  static Future<VIPackageModel?> getPriceInfo({
    required String packageType,
  }) async {
    VIPackageModel? returnData;

    await HttpHelper.get(
      '/api/pay/price/info',
      queryParameters: {"packageType": packageType},
    ).then((value) {
      if (value != null && value.code == 200 && value.data != null) {
        returnData = VIPackageModel.fromJson(value.data);
      }
    });
    return returnData;
  }

  //当前登录用户
  static Future<UserInfoModel?> getCurrentUserLoginInfo() async {
    UserInfoModel? returnData;

    await HttpHelper.get('/api/business/customer/current').then((value) {
      if (value != null && value.code == 200 && value.data != null) {
        returnData = UserInfoModel.fromJson(value.data);
      }
    });

    return returnData;
  }

  //通过手机号查询用户
  static Future<List<UserInfoModel>> searchUserByPhone(String phone) async {
    List<UserInfoModel> returnData = [];

    await HttpHelper.get(
      '/api/business/customer/list',
      queryParameters: {"phone": phone},
    ).then((value) {
      if (value != null && value.code == 200 && value.data != null) {
        returnData = List<UserInfoModel>.from(
          value.data.map((x) => UserInfoModel.fromJson(x)),
        );
      }
    });

    return returnData;
  }

  //更新容量
  static Future<bool> updateQuota(QuotaModel editQuota) async {
    bool returnData = false;

    await HttpHelper.put(
      '/api/business/customer/updateQuota',
      data: {
        {
          "customerId": editQuota.customerId,
          "quatoType": editQuota.quatoType,
          "packageType": editQuota.packageType,
          "addCloudStorageQuotaByte": editQuota.addCloudStorageQuotaByte,
          "addTranscriptionMinutesQuota":
              editQuota.addTranscriptionMinutesQuota,
          "addPlanDuration": editQuota.addPlanDuration,
        },
      },
    ).then((value) {
      if (value?.code == 200) {
        returnData = true;
      }
    });

    return returnData;
  }

  //编辑用户信息
  static Future<ResponseApiModel?> editUserInfo(
    UserInfoModel editUserInfo, {
    String authType = "",
    String confirmPwd = "",
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.put(
      '/api/business/customer/${editUserInfo.id}',
      queryParameters: {"customerId": editUserInfo.id},
      data: {
        "authType": authType, //to be confirm
        "username": editUserInfo.username,
        "password": editUserInfo.password,
        "confirmPassword": confirmPwd,
        "nickname": editUserInfo.nickname,
        "email": editUserInfo.email,
        "phone": editUserInfo.phone,
        "sex": editUserInfo.sex,
        "avatarUrl": editUserInfo.avatarUrl,
        "wxOpenid": editUserInfo.wxOpenid,
        "wxUnionid": editUserInfo.wxUnionid,
        // "sub": editUserInfo.sub,
      },
    ).then((value) {
      // if (value?.code == 200) {
      //   returnData = true;
      // }
      returnData = value;
    });

    return returnData;
  }

  //更新使用时长
  static Future<bool> editUsage({
    required String customerId,
    int? addOssStorageUsage,
    int? addTranscriptionDurationUsage,
  }) async {
    bool returnData = false;

    await HttpHelper.post(
      '/api/business/customer/updateUsage',
      data: {
        "customerId": customerId,
        "addOssStorageUsage": addOssStorageUsage,
        "addTranscriptionDurationUsage": addTranscriptionDurationUsage,
      },
    ).then((value) {
      if (value?.code == 200) {
        returnData = true;
      }
    });

    return returnData;
  }

  static Future<ResponseApiModel?> cancelAccount() async {
    ResponseApiModel? returnData;

    await HttpHelper.post('/api/auth/terminate').then((value) {
      returnData = value;
    });

    return returnData;
  }

  static Future<bool> submitReport({
    required String content,
    String? contact,
    List<SubmitReportModel>? mediaList,
  }) async {
    bool returnData = false;

    await HttpHelper.post(
      '/api/business/feedback/submit',
      data: {
        "content": content,
        "contact": contact,
        "mediaList": mediaList?.map((e) => e.toJson()).toList(),
      },
    ).then((value) {
      if (value?.code == 200) {
        returnData = true;
      }
    });

    return returnData;
  }

  /// 切换手机绑定
  static Future<bool> switchBindPhone({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await HttpHelper.post(
        '/api/auth/updatePhone',
        data: {"captchaCode": code, "newPhone": phone},
      );

      if (response?.code != 200) {
        throw response?.msg ?? '切换手机绑定失败';
      }
      return true;
    } catch (e) {
      DialogHelper.showToastDialog(e.toString());
      return false;
    }
  }
}

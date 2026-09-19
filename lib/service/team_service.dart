import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dting/http/http_helper.dart';
import 'package:dting/model/baseapi/response_api_model.dart';
import 'package:dting/model/file_model/file_management_model/file_info.dart';
import 'package:dting/model/teams_model/inviter_team_model.dart';
import 'package:dting/model/teams_model/teams_model.dart';

class TeamService {
  TeamService._();

  //创建团队
  static Future<ResponseApiModel?> createTeamByUser({
    required String teamName,
    required String avatarUrl,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/business/team/create',
      data: {"teamName": teamName, "avatarUrl": avatarUrl},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //领取奖励
  static Future<ResponseApiModel?> bonusReceive() async {
    ResponseApiModel? returnData;

    await HttpHelper.post('/api/business/customer/bonus').then((value) {
      returnData = value;
    });
    return returnData;
  }

  //切换团队、修改user info中的team
  static Future<bool> changeTeam({required String teamId}) async {
    bool returnData = false;

    await HttpHelper.get(
      '/api/business/customer/changeTeam',
      queryParameters: {"teamId": teamId},
    ).then((value) {
      if (value != null && value.code == 200) {
        returnData = true;
      }
    });
    return returnData;
  }

  //分配积分
  static Future<ResponseApiModel?> allocatePoints({
    required int pointsAmount,
    required String teamId,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/business/team/points/allocate',
      queryParameters: {"pointsAmount": pointsAmount, "teamId": teamId},
    ).then((value) {
      if (value != null) {
        returnData = value;
      }
    });
    return returnData;
  }

  //获取团队列表
  static Future<List<TeamsModel>> getTeamListByUserId() async {
    List<TeamsModel> returnData = [];

    await HttpHelper.get('/api/business/team').then((value) {
      if (value != null && value.data != null) {
        returnData = List<TeamsModel>.from(
          value.data.map((x) => TeamsModel.fromJson(x)),
        );
      }
    });
    return returnData;
  }

  //获取团队信息
  static Future<ResponseApiModel?> getTeamInfoByTeamId({
    required String teamId,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.get('/api/business/team/$teamId').then((value) {
      returnData = value;
    });
    return returnData;
  }

  //接受邀请
  static Future<bool> acceptInviteJointTeam({required String token}) async {
    bool returnData = false;

    await HttpHelper.get(
      '/api/business/team/invite/accept',
      queryParameters: {"token": token},
    ).then((value) {
      if (value != null && value.code == 200) {
        returnData = true;
      }
    });
    return returnData;
  }

  //添加文件分享
  static Future<ResponseApiModel?> shareVoiceFileList({
    required List<String> fileIds,
    required String actionType,
    required List<String> teamIds,
    List<String>? receiverIds,
    required String sourceType,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/business/team/file/share',
      data: {
        "actionType": actionType,
        "fileIds": fileIds,
        "teamIds": teamIds,
        "sourceType": sourceType,
      },
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //团队文件列表
  static Future<List<FileInfoModel>> getFileByTeamId({
    required String teamId,
  }) async {
    List<FileInfoModel> returnData = [];

    await HttpHelper.get(
      '/api/business/team/file/list',
      queryParameters: {"teamId": teamId},
    ).then((value) {
      if (value != null && value.code == 200 && value.data != null) {
        returnData = List<FileInfoModel>.from(
          value.data.map((x) => FileInfoModel.fromJson(x)),
        );
      }
    });
    return returnData;
  }

  //移除团队成员
  static Future<ResponseApiModel?> removeMembersByTeamId({
    required String teamId,
    required String memberInfoId,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.get(
      '/api/business/team/member/remove',
      queryParameters: {"teamId": teamId, "memberInfoId": memberInfoId},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //退出团队
  static Future<ResponseApiModel?> leaveTeamByTeamId({
    required String teamId,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.get(
      '/api/business/team/leave',
      queryParameters: {"teamId": teamId},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //从个人分享文件到团队
  static Future<ResponseApiModel?> shareTeamFiles({
    required List<String> fileIds,
    required String fileSourceType,
    required String actionType,
    required List<String> teamIds,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/business/team/share',
      queryParameters: {
        "fileIds": ["string"],
        "shareType": "string",
        "teamIds": ["string"],
        "receiverIds": ["string"],
        "permissionLevel": "FilePermissionEnums.EDITABLE.getCode()",
      },
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //团队成员角色分配
  static Future<bool> checkTeamAdminOrOwner({
    required int role,
    required String teamId,
    required String memberInfoId,
  }) async {
    bool returnData = false;

    await HttpHelper.get(
      '/api/business/team/member/assign',
      queryParameters: {
        "role": role,
        "teamId": teamId,
        "memberInfoId": memberInfoId,
      },
    ).then((value) {
      if (value != null && value.code == 200) {
        returnData = true;
      }
    });
    return returnData;
  }

  //团队修改信息
  static Future<ResponseApiModel?> editTeamInfoByTeamId({
    String? teamName,
    required String teamId,
    String? avatarUrl,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.put(
      '/api/business/team/$teamId',
      data: {"teamName": teamName, "teamId": teamId, "avatarUrl": avatarUrl},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  ///团队解散
  static Future<ResponseApiModel?> disbandTeam({required String teamId}) async {
    ResponseApiModel? returnData;
    await HttpHelper.delete(
      '/api/business/team/$teamId',
      data: {"teamId": teamId},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //头像上传
  static Future<String?> uploadAvatar({
    required String uploadPath,
    required String filename,
  }) async {
    String? returnData;

    await HttpHelper.post(
      '/api/business/file/presign/uploadPublic',
      queryParameters: {"filename": filename},
    ).then((value) async {
      if (value != null && value.code == 200) {
        if (value.data["url"] != null) {
          await uploadOSSFile(
            uploadPath: uploadPath,
            url: value.data["url"],
            contentType: value.data["headers"]["Content-Type"],
          ).then((val) {
            returnData = value.data["url"];
          });
        }
      }
    });

    return returnData;
  }

  //文件上传 SearchFileByCategoryModel
  static Future<bool> uploadOSSFile({
    required String url,
    required String uploadPath,
    required String contentType,
  }) async {
    bool returnData = false;
    final file = File(uploadPath);
    final fileBytes = await file.readAsBytes();
    // 4. 上传到 OSS
    print(url);
    await Dio()
        .put(
          url,
          data: fileBytes,
          options: Options(
            headers: {
              'Content-Type': contentType,
              'Content-Length': fileBytes.length,
            },
          ),
        )
        .then((value) {
          if (value.statusCode == 200) {
            returnData = true;
          }
        });
    return returnData;
  }

  //编辑团队文件
  static Future<ResponseApiModel?> editFile({
    required String fileId,
    required String filename,
  }) async {
    ResponseApiModel? returnData;
    await HttpHelper.put(
      '/api/business/team/file/$fileId',
      queryParameters: {"fileId": fileId},
      data: {"newOriginalFilename": filename},
    ).then((value) {
      returnData = value;
    });

    return returnData;
  }

  static Future<ResponseApiModel?> deleteTeamFileByTeamId({
    required String teamId,
    required List<String> fileIds,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.delete(
      '/api/business/team/file/remove',
      queryParameters: {"fileIds": fileIds, "teamId": teamId},
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  // //发起转写
  // static Future<ResponseApiModel?> transResponseByTeam({
  //   required String fileId,
  //   required String teamId,
  // }) async {
  //   ResponseApiModel? returnData;

  //   await HttpHelper.post(
  //     '/api/business/team/file/trans',
  //     queryParameters: {"fileId": fileId, "teamId": teamId},
  //   ).then((value) {
  //     returnData = value;
  //   });
  //   return returnData;
  // }

  // //转写回调
  // static Future<List<TransModel>?> transCallBackByTeam({
  //   required String taskId,
  //   required String teamId,
  // }) async {
  //   List<TransModel>? returnData;

  //   await HttpHelper.get(
  //     '/api/business/team/file/trans/get',
  //     queryParameters: {"taskId": taskId, "teamId": teamId},
  //   ).then((value) {
  //     if (value != null && value.code == 200) {
  //       returnData = List<TransModel>.from(
  //         value.data.map((x) => TransModel.fromJson(x)),
  //       );
  //     }
  //   });
  //   return returnData;
  // }

  // //团队文件发起概括、总结、思维导图
  // static Future<ResponseApiModel?> getAIByTeam({
  //   required String operType,
  //   required String fileId,
  //   required String teamId,
  // }) async {
  //   ResponseApiModel? returnData;

  //   await HttpHelper.post(
  //     '/api/business/team/file/ai',
  //     queryParameters: {
  //       "operType": operType,
  //       "fileId": fileId,
  //       "teamId": teamId,
  //     },
  //   ).then((value) {
  //     returnData = value;
  //   });
  //   return returnData;
  // }

  //个人权益升级
  static Future<bool> upgradePersonToTeam() async {
    bool returnData = false;

    await HttpHelper.get('/api/business/customer/grantTeamUpgrade').then((
      value,
    ) {
      if (value != null && value.code == 200) {
        returnData = true;
      }
    });
    return returnData;
  }

  static Future<FileInfoModel?> getFileInfoByTeamId({
    required String fileId,
    required String teamId,
  }) async {
    FileInfoModel? returnData;

    await HttpHelper.get(
      '/api/business/team/file/info',
      queryParameters: {"fileId": fileId, "teamId": teamId},
    ).then((value) {
      if (value != null && value.data != null) {
        returnData = FileInfoModel.fromJson(value.data);
      }
    });
    return returnData;
  }

  //我的邀请连接
  static Future<List<InviterTeamModel>> getInviteList() async {
    List<InviterTeamModel> returnData = [];

    await HttpHelper.get('/api/business/team/invite/mine').then((value) {
      if (value != null && value.data != null) {
        returnData = List<InviterTeamModel>.from(
          value.data.map((x) => InviterTeamModel.fromJson(x)),
        );
      }
    });
    return returnData;
  }

  //发起邀请
  static Future<ResponseApiModel?> postInvite({
    required String teamId,
    required List<String> inviteePhoneList,
    int inviteRole = 0,
    int? validMinutes,
  }) async {
    ResponseApiModel? returnData;

    await HttpHelper.post(
      '/api/business/team/invite/create',
      data: {
        "teamId": teamId,
        "inviteePhones": inviteePhoneList,
        "inviteRole": inviteRole,
        "validMinutes": validMinutes,
      },
    ).then((value) {
      returnData = value;
    });
    return returnData;
  }

  //处理邀请
  //accept/reject
  static Future<bool> handerInvite({
    required String action,
    required String invitationId,
  }) async {
    bool returnData = false;

    await HttpHelper.get(
      '/api/business/team/invite/$invitationId',
      queryParameters: {"invitationId": invitationId, "action": action},
    ).then((value) {
      if (value != null && value.code == 200) {
        returnData = true;
      }
    });
    return returnData;
  }
}

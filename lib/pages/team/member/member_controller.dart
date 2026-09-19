import 'package:dting/model/teams_model/members_model.dart';
import 'package:dting/pages/team/team_index/team_file_controller.dart';
import 'package:dting/service/personal_service.dart';
import 'package:dting/service/team_service.dart';
import 'package:dting/store/dting_store.dart';
import 'package:dting/utils/local_database.dart';
import 'package:dting/utils/logger_utils.dart';
import 'package:dting/widgets/dialog/dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class MemberController extends GetxController {
  // 团队成员列表
  var membersList = <MembersModel>[].obs;
  var teamFileController = Get.find<TeamFileController>();
  var appController = Get.find<DtingStore>();

  // 当前团队ID
  String? get currentTeamId => appController.userInfo.value.teamId;

  var selectMember = MembersModel.genDefault().obs; //当前选择的成员
  @override
  void onInit() {
    super.onInit();
    // initCurrentTeamMemberList();
    membersList.value = teamFileController.currentMemberList;
    getAllTeamList();
  }

  @override
  void onClose() {
    super.onClose();
  }

  //获取团队数据
  Future<void> getAllTeamList() async {
    if (appController.teamsList.isEmpty) {
      await TeamService.getTeamListByUserId().then((val) {
        appController.teamsList.value = val;
      });
    }
  }

  //邀请新成员
  Future<void> inviteMemberJoinOurTeam({
    required List<String> inviteePhoneList,
    bool back = true,
  }) async {
    await EasyLoading.show();
    try {
      if (currentTeamId != null &&
          currentTeamId != "-1" &&
          inviteePhoneList.isNotEmpty) {
        TeamService.postInvite(
          teamId: currentTeamId!,
          inviteePhoneList: inviteePhoneList,
        ).then((invite) async {
          if (invite != null) {
            if (invite.code == 200) {
              await teamFileController.getCurrentTeamDetail();
              membersList.value = teamFileController.currentMemberList;
              Get.back();
              DialogHelper.showToastDialog("inviteSuccessful");
            } else {
              var message = invite.msg;
              DialogHelper.showToastDialog(message);
            }
            await EasyLoading.dismiss();
          }
        });
      }
    } catch (e) {
      await EasyLoading.dismiss();
    }
  }

  Future<void> clickInvitationLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    DialogHelper.showToastDialog("copySuccess");
    Get.back();
  }

  //移除团队成员
  void reMoveMemberByTeamId() {
    if (currentTeamId != null && currentTeamId != "-1") {
      TeamService.removeMembersByTeamId(
        teamId: currentTeamId!,
        memberInfoId: selectMember.value.id,
      ).then((val) async {
        Get.back();
        if (val != null) {
          if (val.code == 200) {
            await teamFileController.getCurrentTeamDetail();
            membersList.value = teamFileController.currentMemberList;
          } else {
            var mes = val.msg;
            DialogHelper.showToastDialog(mes);
          }
        }
      });
    }
  }

  //设置管理员权限
  void administrativeForMember({int roleInt = 0, bool back = false}) {
    var tempRole = 0;
    if (roleInt == 2) {
      //设置成所有者
      tempRole = 2;
    } else {
      if (selectMember.value.role == 0) {
        tempRole = 1;
      }
    }
    TeamService.checkTeamAdminOrOwner(
      role: tempRole,
      teamId: teamFileController.currentTeam.value.id,
      memberInfoId: selectMember.value.id,
    ).then((val) async {
      if (val) {
        await teamFileController.getCurrentTeamDetail();
        membersList.value = teamFileController.currentMemberList;
        if (back) {
          Get.back();
        }
      } else {
        DialogHelper.showToastDialog("movePermissionsFail");
      }
    });
  }

  //修改团队名称
  void editTeamName(String editTeamName) {
    TeamService.editTeamInfoByTeamId(
      teamId: teamFileController.currentTeam.value.id,
      teamName: editTeamName,
    ).then((val) {
      if (val != null && val.code == 200) {
        var isExist = appController.teamsList.firstWhereOrNull(
          (team) => team.id == currentTeamId,
        );
        if (isExist != null) {
          isExist.teamName = editTeamName;
        }
        teamFileController.currentTeam.value.teamName = editTeamName;
        teamFileController.currentTeam.refresh();
        appController.teamsList.refresh();
        Get.back();
      } else {
        var message = val!.msg;
        DialogHelper.showToastDialog(message);
      }
    });
  }

  //删除或者退出团队
  void deleteOrLeaveTeam() {
    if (teamFileController.currentTeam.value.currentCustomerRole == 2) {
      //群主 解散团队
      disbandTeam();
    } else {
      //退出团队
      quitTeam();
    }
  }

  //退出选中的团队
  void quitTeam() {
    TeamService.leaveTeamByTeamId(
      teamId: teamFileController.currentTeam.value.id,
    ).then((val) {
      print('退出团队val=${val}');
      if (val != null) {
        if (val.code == 200) {
          //解散团队积分回到个人
          appController.getAllTeamList();
          //通过个人详情数据的teamID 来判断当前的teamId
          PersonalService.getCurrentUserLoginInfo().then((user) async {
            if (user != null) {
              appController.userInfo.value = user;
              teamFileController.refreshTeamData();
              await EasyLoading.dismiss();
              Get.back();
            }
          });
        } else {
          var mes = val.msg;
          DialogHelper.showToastDialog(mes);
        }
      }
    });
  }

  //解散团队
  Future<void> disbandTeam() async {
    await EasyLoading.show();
    try {
      print('解散团队');
      TeamService.disbandTeam(
        teamId: teamFileController.currentTeam.value.id,
      ).then((val) async {
        print('解散团队 val=${val}');
        if (val != null && val.code == 200) {
          //解散团队积分回到个人
          appController.getAllTeamList();
          //通过个人详情数据的teamID 来判断当前的teamId
          PersonalService.getCurrentUserLoginInfo().then((user) async {
            if (user != null) {
              appController.userInfo.value = user;
              teamFileController.refreshTeamData();
              await EasyLoading.dismiss();
              Get.back();
            }
          });
        } else {
          var mes = val!.msg;
          DialogHelper.showToastDialog(mes);
        }
      });
    } catch (e) {
      await EasyLoading.dismiss();
    }
  }

  //移除或者退出团队
  void removeMemberOrQuitTeam() {
    if (teamFileController.currentTeam.value.currentCustomerRole != 0) {
      reMoveMemberByTeamId(); //移除成员
    } else {
      quitTeam(); //退出团队
    }
  }
}

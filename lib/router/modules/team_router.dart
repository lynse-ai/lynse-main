import 'package:dting/pages/team/add_seats/add_seats_binding.dart';
import 'package:dting/pages/team/add_seats/add_seats_page.dart';
import 'package:dting/pages/team/member/change_owner.dart';
import 'package:dting/pages/team/member/member_binding.dart';
import 'package:dting/pages/team/member/member_page.dart';
import 'package:dting/pages/team/search/team_search_file_binding.dart';
import 'package:dting/pages/team/search/team_search_file_page.dart';
import 'package:dting/pages/team/share_team_select_file/share_team_select_file_binding.dart';
import 'package:dting/pages/team/share_team_select_file/share_team_select_file_page.dart';
import 'package:dting/pages/team/team_point_history/team_point_history_binding.dart';
import 'package:dting/pages/team/team_point_history/team_point_history_page.dart';
import 'package:dting/pages/team/team_purchase_points/team_purchase_points_binding.dart';
import 'package:dting/pages/team/team_purchase_points/team_purchase_points_page.dart';
import 'package:get/get_navigation/src/routes/get_route.dart';
import 'package:dting/pages/team/team_index/team_file_binding.dart';
import 'package:dting/pages/team/team_index/team_file_page.dart';

class TeamRouter {
  static final teamfiles = '/teamfile';
  static final shareteam = '/share_team';
  static final shareTeamMembers = '/share_team_members';
  static final members = '/members';
  static final teampurchase = '/team_purchase_point';
  static final addseats = '/addseats';
  static final teams = '/teams';
  static final searchTeams = '/search_teams';
  static final teamsVoiceDetail = '/teams_voice_detail';
  static final changeMembers = '/change_members';
  static final shareTeamFile = '/share_team_file';
  static final teamPointHistory = '/team_point_history';

  static final pages = [
    GetPage(
      name: searchTeams,
      page: () => const TeamSearchFilePage(),
      binding: TeamSearchFileBinding(),
    ),
    GetPage(
      name: shareTeamFile,
      page: () => const ShareTeamSelectFilePage(),
      binding: ShareTeamSelectFileBinding(),
    ),

    GetPage(
      name: teamfiles,
      page: () => const TeamFilePage(),
      binding: TeamFileBinding(),
    ),
    GetPage(
      name: members,
      page: () => const MemberPage(),
      binding: MemberBinding(),
    ),
    GetPage(
      name: changeMembers,
      page: () => const ChangeOwnerWidget(),
      binding: MemberBinding(),
    ),
    GetPage(
      name: teampurchase,
      page: () => const TeamPurchasePointsPage(),
      binding: TeamPurchasePointsBinding(),
    ),

    GetPage(
      name: addseats,
      page: () => const AddSeatsPage(),
      binding: AddSeatsBinding(),
    ),
    GetPage(
      name: teamPointHistory,
      page: () => TeamPointHistoryPage(),
      binding: TeamPointHistoryBinding(),
    ),
  ];
}

import 'package:dting/pages/personal/download/download_file/download_file_binding.dart';
import 'package:dting/pages/personal/download/download_file/download_file_page.dart';
import 'package:dting/pages/personal/download/download_folder/download_folder_binding.dart';
import 'package:dting/pages/personal/download/download_folder/download_folder_page.dart';
import 'package:dting/pages/personal/language/language_binding.dart';
import 'package:dting/pages/personal/language/language_page.dart';
import 'package:dting/pages/personal/my/user_page.dart';
import 'package:dting/pages/personal/point_history/point_history_binding.dart';
import 'package:dting/pages/personal/point_history/point_history_page.dart';
import 'package:dting/pages/personal/purchase_points/purchase_points_binding.dart';
import 'package:dting/pages/personal/purchase_points/purchase_points_page.dart';
import 'package:dting/pages/personal/report/report_binding.dart';
import 'package:dting/pages/personal/report/report_page.dart';
import 'package:get/get.dart';

import 'package:dting/pages/personal/about/about_binding.dart';
import 'package:dting/pages/personal/about/about_page.dart';
import 'package:dting/pages/personal/help/help_binding.dart';
import 'package:dting/pages/personal/help/help_page.dart';
import 'package:dting/pages/personal/my/my_binding.dart';
import 'package:dting/pages/personal/my/my_page.dart';

class PersonalRouter {
  static final my = '/my';
  static final user = '/user';
  static final help = '/help';
  static final about = '/about';
  static final downloadfile = '/download';
  static final downloadfolder = '/downloadfolder';
  static final report = '/report';
  static final pointhistory = '/pointhistory';
  static final purchase = '/purchase';
  static final language = '/language';

  static final pages = [
    GetPage(
      name: language,
      page: () => const LanguagePage(),
      binding: LanguageBinding(),
    ),
    GetPage(
      name: my,
      page: () => const MyPage(),
      binding: MyBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(name: user, page: () => const UserPage(), binding: MyBinding()),
    GetPage(
      name: help,
      page: () => const HelpAndFeedBackPage(),
      binding: HelpAndFeedBackBinding(),
    ),
    GetPage(
      name: about,
      page: () => const AboutPage(),
      binding: AboutBinding(),
    ),
    GetPage(
      name: downloadfile,
      page: () => const DownloadFilePage(),
      binding: DownloadFileBinding(),
    ),
    GetPage(
      name: downloadfolder,
      page: () => const DownloadFolderPage(),
      binding: DownloaFolderdBinding(),
    ),
    GetPage(
      name: report,
      page: () => const ReportPage(),
      binding: ReportBinding(),
    ),
    GetPage(
      name: pointhistory,
      page: () => const PointHistoryPage(),
      binding: PointHistoryBinding(),
    ),
    GetPage(
      name: purchase,
      page: () => const PurchasePointsPage(),
      binding: PurchasePointsBinding(),
    ),
  ];
}

import 'package:dting/pages/device/menu/concel/concel_binding.dart';
import 'package:dting/pages/device/menu/concel/concel_page.dart';
import 'package:dting/pages/device/search_device/search_device_binding.dart';
import 'package:dting/pages/device/search_device/search_device_page.dart';
import 'package:dting/pages/device/voice_details/voicedetails_binding.dart';
import 'package:dting/pages/device/voice_details/voicedetails_page.dart';
import 'package:dting/pages/device/connectdevice/connectdevice_binding.dart';
import 'package:dting/pages/device/connectdevice/connectdevice_page.dart';
import 'package:dting/pages/home/home_index/homeindex_binding.dart';
import 'package:dting/pages/home/home_index/homeindex_page.dart';
import 'package:dting/pages/home/recycle_bin/recycle_bin_binding.dart';
import 'package:dting/pages/home/recycle_bin/recycle_bin_page.dart';
import 'package:dting/pages/home/search/search_file_binding.dart';
import 'package:dting/pages/home/search/search_file_page.dart';
import 'package:dting/pages/home/folder_manage/folder_manage_page.dart';
import 'package:dting/pages/home/folder_manage/folder_manage_binding.dart';
import 'package:get/get.dart';

import 'package:dting/pages/device/bootstrapoperation/bootstrapoperation_binding.dart';
import 'package:dting/pages/device/bootstrapoperation/bootstrapoperation_page.dart';
import 'package:dting/pages/home/homeprompt/homeprompt_binding.dart';
import 'package:dting/pages/home/homeprompt/homeprompt_page.dart';
import 'package:dting/pages/home/hometip/hometip_binding.dart';
import 'package:dting/pages/home/hometip/hometip_page.dart';

class HomeRouter {
  static final hometip = '/hometip';
  static final recyclebin = '/recyclebin';
  static final connectdevice = '/connectdevice';
  static final bootstrapoperation = '/bootstrapoperation';
  static final homeindex = '/homeindex';
  static final homeprompt = '/homefolder';
  static final search = '/search';
  static final voiceplay = '/voiceplay';
  static final concel = '/concel';
  static final voicedetails = '/voicedetails';
  static final voicedetailsV2 = '/voicedetails_v2';
  static final folderManage = '/folderManage';
  static final searchDevice = '/searchDevice';

  static final pages = [
    GetPage(
      name: folderManage,
      page: () => FolderManagePage(),
      binding: SideBarBinding(),
    ),
    GetPage(
      name: voicedetails,
      page: () => VoiceDetailsPage(),
      binding: VoiceDetailsBinding(),
    ),

    GetPage(
      name: concel,
      page: () => const ConcelPage(),
      binding: ConcelBinding(),
    ),
    GetPage(
      name: recyclebin,
      page: () => const RecycleBinPage(),
      binding: RecycleBinBinding(), //多语言
    ),

    GetPage(
      name: hometip,
      page: () => const HomeTipPage(),
      binding: HomeTipBinding(),
    ),
    GetPage(
      name: connectdevice,
      page: () => const ConnectDevicePage(),
      binding: ConnectDeviceBinding(),
    ),
    GetPage(
      name: searchDevice,
      page: () => const SearchDevicePage(),
      binding: SearchDeviceBinding(),
    ),
    GetPage(
      name: bootstrapoperation,
      page: () => const BootstrapOperationPage(),
      binding: BootstrapOperationBinding(),
    ),
    GetPage(
      name: homeindex,
      page: () => const HomeIndexPage(),
      binding: HomeIndexBinding(),
    ),

    GetPage(
      name: homeprompt,
      page: () => const HomePromptPage(),
      binding: HomePromptBinding(),
    ),

    GetPage(name: search, page: () => SearchPage(), binding: SearchBinding()),
  ];
}

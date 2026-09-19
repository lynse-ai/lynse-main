import 'package:dting/pages/device/device_details/managedevice_binding.dart';
import 'package:dting/pages/device/device_details/managedevice_page.dart';
import 'package:get/get.dart';

class ManageDeviceRouter {
  static final managedevice = '/managedevice';
  // static final devicedetails = '/devicedetails';
  // static final recordinghome = '/recordinghome';
  // static final deviceOta = '/device/ota';

  static final pages = [
    GetPage(
      name: managedevice,
      page: () => const ManageDevicePage(),
      binding: ManageDeviceBinding(),
    ),
  ];
}

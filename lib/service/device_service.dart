import 'package:dting/http/http_helper.dart';
import 'package:dting/model/device_model/deviceinfo_model.dart';
import 'package:dting/model/device_model/search_device_model.dart';

class DeviceService {
  DeviceService._();

  //绑定设备
  static Future<bool> bindDevice({
    required String macAddress,
    String? deviceName,
    String? serialNumber,
    String? version,
  }) async {
    bool returnData = false;

    await HttpHelper.post(
      '/api/business/device/bind',
      data: {
        "macAddress": macAddress,
        "version": version,
        "serialNumber": serialNumber,
        "deviceName": deviceName,
      },
    ).then((value) {
      if (value?.code == 200) {
        returnData = true;
      }
    });

    return returnData;
  }

  //查看多个设备绑定状态
  static Future<List<SearchBindDeviceModel>> getBindList({
    required List<String> macAddressList,
  }) async {
    List<SearchBindDeviceModel> returnData = [];

    String macAddressListString = macAddressList.join(',');
    await HttpHelper.get(
      '/api/business/device/isBound',
      queryParameters: {"macAddressList": macAddressListString},
    ).then((value) {
      if (value != null && value.code == 200) {
        returnData = List<SearchBindDeviceModel>.from(
          value.data.map((x) => SearchBindDeviceModel.fromJson(x)),
        );
      }
    });

    return returnData;
  }

  //我的设备
  static Future<List<DeviceInfoModel>> getDeviceList() async {
    List<DeviceInfoModel> returnData = [];

    await HttpHelper.get('/api/business/device/mine').then((value) {
      if (value != null && value.code == 200) {
        returnData = List<DeviceInfoModel>.from(
          value.data.map((x) => DeviceInfoModel.fromJson(x)),
        );
      }
    });

    return returnData;
  }

  //解绑设备
  static Future<bool> unBindDevice({required String macAddress}) async {
    bool returnData = false;
    await HttpHelper.get(
      '/api/business/device/unbind',
      queryParameters: {"macAddress": macAddress},
    ).then((value) {
      if (value != null && value.code == 200) {
        returnData = true;
      }
    });

    return returnData;
  }

  static Future<bool> editDeviceNameByUuid({
    required String macAddress,
    required String editName,
    String? version,
    String? serialNumber,
  }) async {
    bool returnData = false;
    await HttpHelper.put(
      '/api/business/device/update',
      data: {
        "macAddress": macAddress,
        "deviceName": editName,
        "version": version,
        "serialNumber": serialNumber,
      },
    ).then((value) {
      if (value != null && value.code == 200) {
        returnData = true;
      }
    });

    return returnData;
  }

  static Future<bool> updateDeviceConnectTime({
    required String macAddress,
  }) async {
    bool returnData = false;
    await HttpHelper.put(
      '/api/business/device/updateConnectTime',
      queryParameters: {"macAddress": macAddress},
    ).then((value) {
      if (value != null && value.code == 200) {
        returnData = true;
      }
    });

    return returnData;
  }
}

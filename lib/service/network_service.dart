import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class NetworkService extends GetxService {
  static NetworkService get to => Get.find();

  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  var isConnected = false.obs;
  var connectionType = ConnectivityResult.none.obs;

  final List<Function()> _onConnectedCallbacks = [];
  final List<Function()> _onDisconnectedCallbacks = [];

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (error) => print('网络状态检查失败: $error'),
      onDone: () => print('网络状态检查完成'),
      cancelOnError: true,
    );
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }

  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      print('网络状态检查失败: $e');
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    final wasConnected = isConnected.value;

    connectionType.value = result;
    isConnected.value = result != ConnectivityResult.none;

    print('网络状态变化: ${result.name}, 连接状态: ${isConnected.value}');

    // 网络状态变化回调
    if (!wasConnected && isConnected.value) {
      // 从断网恢复到联网
      for (final callback in _onConnectedCallbacks) {
        callback();
      }
    } else if (wasConnected && !isConnected.value) {
      // 从联网变为断网
      for (final callback in _onDisconnectedCallbacks) {
        callback();
      }
    }
  }

  void addOnConnectedCallback(Function() callback) {
    _onConnectedCallbacks.add(callback);
  }

  void addOnDisconnectedCallback(Function() callback) {
    _onDisconnectedCallbacks.add(callback);
  }

  void removeOnConnectedCallback(Function() callback) {
    _onConnectedCallbacks.remove(callback);
  }

  void removeOnDisconnectedCallback(Function() callback) {
    _onDisconnectedCallbacks.remove(callback);
  }
}

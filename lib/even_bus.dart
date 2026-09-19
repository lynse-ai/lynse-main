import 'package:event_bus/event_bus.dart';

EventBus eventBus = EventBus();

// 蓝牙连接成功
class BluetoothConnectedEvent {
  final String deviceName;
  final String deviceUuid;

  BluetoothConnectedEvent(this.deviceName, this.deviceUuid);
}

// 蓝牙断开连接
class BluetoothDisconnectedEvent {
  BluetoothDisconnectedEvent();
}

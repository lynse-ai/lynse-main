/// Lynse 硬件抽象层统一出口。
///
/// 业务/UI 只 import 本文件：
/// ```dart
/// import 'package:dting/hardware/hardware_kit.dart';
/// ```
library;

export 'ble_device_adapter.dart';
export 'hardware_event.dart';
export 'models.dart';
export 'neview/neview_adapter.dart';
export 'xyrix/xyrix_adapter.dart';
export 'xyrix/xyrix_commands.dart';
export 'xyrix/xyrix_frame_codec.dart';

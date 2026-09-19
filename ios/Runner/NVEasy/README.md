# iOS NVEasy Plugin - downloadFile 功能实现

## 概述

本文档描述了 iOS 端 `nv_easy_plugin` 插件中 `downloadFile` 功能的实现。

## 实现的功能

### 1. downloadFile (蓝牙下载)
- **方法名**: `downloadFile`
- **参数**: `sn` (Int) - 文件序列号
- **功能**: 通过蓝牙连接下载设备中的音频文件
- **实现位置**: `ios/Runner/NVEasy/NVEasyPlugin.swift`

### 2. downloadFileOfWifi (WiFi 快传)
- **方法名**: `downloadFileOfWifi`
- **参数**: `sn` (Int) - 文件序列号
- **功能**: 通过 WiFi 快传方式下载设备中的音频文件
- **实现位置**: `ios/Runner/NVEasy/NVEasyPlugin.swift`

### 3. deviceOta (OTA 升级) ✅ 已完善
- **方法名**: `deviceOta`
- **参数**: 
  - `otaFilePath` (String) - OTA 文件路径
  - `newVersion` (String) - 新版本号
- **功能**: 执行设备 OTA 升级
- **实现位置**: `ios/Runner/NVEasy/NVEasyPlugin.swift`
- **状态回调**: 通过 `deviceUpdateOtaStatus` 事件向 Flutter 发送升级状态

## OTA 升级功能详细说明

### 状态码定义
iOS 端 OTA 升级状态与 Android 端保持一致：

- `0` - STARTED (升级开始)
- `1` - PROGRESS (升级中)
- `2` - SUCCESS (升级成功)
- `3` - FAILED (升级失败)

### 实现细节

1. **文件验证**: 检查 OTA 文件是否存在
2. **升级执行**: 调用 `NVEasyOTAManager.upgrade(to:with:)` 方法
3. **状态回调**: 通过 `NVEasyHardwareDelegate` 协议接收升级状态
4. **Flutter 通知**: 使用 `MethodChannel` 发送 `deviceUpdateOtaStatus` 事件

### 回调方法

```swift
// 升级开始
func otaManager(didStart otaManager: NVEasyOTAManager)

// 升级结束
func otaManager(didEnd otaManager: NVEasyOTAManager)

// 升级进度
func otaManager(_ otaManager: NVEasyOTAManager, progress: Double, error: (any Error)?)
```

### 错误处理

- 文件不存在时返回 `FILE_NOT_FOUND` 错误
- 参数缺失时返回 `INVALID_ARGUMENTS` 错误
- 升级过程中的错误通过 `deviceUpdateOtaStatus` 事件发送

## 实现细节

### 文件下载流程

1. **接收 Flutter 调用**: 通过 `MethodChannel` 接收来自 Flutter 的方法调用
2. **参数验证**: 检查必需的参数是否存在
3. **调用 SDK**: 使用 `NVEasyFileManager.shared.getFile()` 方法开始文件下载
4. **通知 Flutter**: 通过 `MethodChannel` 发送 `bleStartGetFile` 事件通知 Flutter 端

### 错误处理

- 参数缺失时返回 `FlutterError`
- 使用 `FlutterMethodNotImplemented` 处理未实现的方法

### 与 Android 端的差异

| 功能 | iOS 端 | Android 端 |
|------|--------|------------|
| 蓝牙下载 | ✅ 已实现 | ✅ 已实现 |
| WiFi 快传 | ✅ 已实现 | ✅ 已实现 |
| OTA 升级 | ✅ 已实现 | ✅ 已实现 |
| 多设备支持 | ✅ 支持 | ❌ 不支持 |
| UDP 网络传输 | ✅ 支持 | ❌ 不支持 |

## 使用方法

### Flutter 端调用

```dart
// 蓝牙下载
await NvEasyPlugin().downLoadFile(fileSN);

// WiFi 快传下载
await NvEasyPlugin().downLoadFileWifi(fileSN);

// OTA 升级
await NvEasyPlugin().otaUpgrade(otaFilePath, newVersion);
```

### OTA 升级状态监听

```dart
// 在 Flutter 端监听 OTA 升级状态
// 状态会通过 deviceUpdateOtaStatus 事件发送
// 包含 status, progress, upgradedSize, error 字段
```

## 注意事项

1. **文件路径**: OTA 文件路径必须是有效的本地文件路径
2. **版本格式**: 版本号格式需要与设备固件版本格式一致
3. **设备连接**: 执行 OTA 升级前需要确保设备已连接
4. **升级过程**: 升级过程中请勿断开设备连接或关闭应用 
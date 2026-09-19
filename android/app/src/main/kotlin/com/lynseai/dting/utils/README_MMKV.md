# MMKV工具类使用说明

## 概述

本项目使用腾讯开源的MMKV库来实现高性能的键值存储，特别用于存储断点续传信息。MMKV是一个基于mmap的高性能键值存储框架，具有以下优势：

- **高性能**：基于mmap内存映射，读写速度极快
- **稳定性**：经过腾讯多个产品验证，稳定可靠
- **跨平台**：支持Android、iOS、macOS、Windows等平台
- **易用性**：API简单，使用方便

## 文件结构

```
utils/
├── BreakpointResumeInfo.kt      # 断点续传信息数据类
├── MMKVUtils.kt                 # MMKV工具类（单例模式）
├── MMKVUsageExample.kt          # 使用示例
└── README_MMKV.md              # 本说明文件
```

## 核心功能

### 1. 断点续传信息存储

支持存储以下断点续传信息：
- `mBPResumeSN`: 断点续传文件序列号
- `mBPResumeOffset`: 断点续传偏移量（已下载的字节数）
- `mBPResumeName`: 断点续传文件名
- `mBPResumeFilePath`: 断点续传文件路径

### 2. 两种存储方式

#### 方式一：对象存储（推荐）
```kotlin
// 保存断点续传信息
val resumeInfo = BreakpointResumeInfo(
    mBPResumeSN = 12345,
    mBPResumeOffset = 1024000,
    mBPResumeName = "example_file.mp3",
    mBPResumeFilePath = "/storage/emulated/0/Download/example_file.mp3"
)
MMKVUtils.getInstance().saveBreakpointResumeInfo(resumeInfo)

// 获取断点续传信息
val resumeInfo = MMKVUtils.getInstance().getBreakpointResumeInfo()
if (resumeInfo.isValid()) {
    // 使用断点续传信息
    println("序列号: ${resumeInfo.mBPResumeSN}")
    println("偏移量: ${resumeInfo.mBPResumeOffset}")
}
```

#### 方式二：单个字段存储
```kotlin
val mmkvUtils = MMKVUtils.getInstance()

// 保存单个字段
mmkvUtils.saveBPResumeSN(12345)
mmkvUtils.saveBPResumeOffset(1024000)
mmkvUtils.saveBPResumeName("example_file.mp3")
mmkvUtils.saveBPResumeFilePath("/storage/emulated/0/Download/example_file.mp3")

// 获取单个字段
val sn = mmkvUtils.getBPResumeSN()
val offset = mmkvUtils.getBPResumeOffset()
val name = mmkvUtils.getBPResumeName()
val filePath = mmkvUtils.getBPResumeFilePath()
```

## 初始化

在Application类中初始化MMKV：

```kotlin
class DtingApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // 初始化MMKV
        MMKVUtils.initialize(this)
    }
}
```

确保在AndroidManifest.xml中注册Application类：

```xml
<application
    android:name=".DtingApplication"
    android:label="谛听记"
    android:icon="@mipmap/ic_launcher">
    ...
</application>
```

## 常用操作

### 检查是否存在断点续传信息
```kotlin
if (MMKVUtils.getInstance().hasBreakpointResumeInfo()) {
    // 存在断点续传信息，可以继续下载
} else {
    // 不存在，开始新的下载
}
```

### 更新下载进度
```kotlin
val resumeInfo = MMKVUtils.getInstance().getBreakpointResumeInfo()
resumeInfo.mBPResumeOffset = newOffset
MMKVUtils.getInstance().saveBreakpointResumeInfo(resumeInfo)
```

### 清空断点续传信息
```kotlin
MMKVUtils.getInstance().clearBreakpointResumeInfo()
```

## 通用存储方法

除了断点续传信息，MMKVUtils还提供了通用的存储方法：

```kotlin
val mmkvUtils = MMKVUtils.getInstance()

// 字符串
mmkvUtils.putString("key", "value")
val value = mmkvUtils.getString("key")

// 整数
mmkvUtils.putInt("key", 123)
val intValue = mmkvUtils.getInt("key")

// 布尔值
mmkvUtils.putBoolean("key", true)
val boolValue = mmkvUtils.getBoolean("key")

// 长整数
mmkvUtils.putLong("key", 123L)
val longValue = mmkvUtils.getLong("key")

// 浮点数
mmkvUtils.putFloat("key", 1.23f)
val floatValue = mmkvUtils.getFloat("key")
```

## 依赖配置

确保在`android/app/build.gradle.kts`中添加了以下依赖：

```kotlin
dependencies {
    // MMKV - 腾讯高性能键值存储库
    implementation("com.tencent:mmkv:1.3.5")
    
    // Kotlin序列化库
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
}
```

并在plugins中添加：

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("kotlinx-serialization")
    id("dev.flutter.flutter-gradle-plugin")
}
```

## 最佳实践

1. **单例模式**：MMKVUtils使用单例模式，确保全局只有一个实例
2. **线程安全**：MMKV本身是线程安全的，可以在多线程环境中使用
3. **错误处理**：工具类内置了错误处理机制，序列化失败时会自动降级到单字段存储
4. **兼容性**：支持对象存储和单字段存储两种方式，确保向后兼容
5. **性能优化**：使用JSON序列化存储对象，读写性能优异

## 注意事项

1. 必须在Application中初始化MMKV，否则会抛出异常
2. 建议使用对象存储方式，更加便于管理和扩展
3. 断点续传信息会持久化存储，应用重启后仍然有效
4. 清空断点续传信息时，会同时清空对象存储和单字段存储的数据

## 示例代码

详细的使用示例请参考 `MMKVUsageExample.kt` 文件，其中包含了完整的断点续传流程示例。
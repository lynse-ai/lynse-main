pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Flutter 3.47 要求 AGP >= 8.11.1；停在 8.x 最新稳定版，
    // 不跨到 AGP 9 —— 9+ 只读新 DSL，会击穿 gradle.properties 里的 android.newDsl=false
    id("com.android.application") version "8.13.2" apply false
    // Flutter 3.47 要求 Kotlin >= 2.2.20；取 2.2 线的最新补丁版，
    // 不追 2.3/2.4 —— 与 AGP 8.13 搭配时越保守越少踩编译期不兼容
    id("org.jetbrains.kotlin.android") version "2.2.21" apply false
}

include(":app")

include(":lynse-adapter-kit")
project(":lynse-adapter-kit").projectDir = file("../lynse-hardware-sdk/adapter-kit/android")
include(":lynse-native-core")
project(":lynse-native-core").projectDir = file("../lynse-hardware-sdk/native-core/android")
include(":lynse-protocol-kit")
project(":lynse-protocol-kit").projectDir = file("../lynse-hardware-sdk/protocol-kit/android")
include(":lynse-android-platform-driver")
project(":lynse-android-platform-driver").projectDir = file("../lynse-hardware-sdk/platform-driver/android")
include(":lynse-newview-protocol")
project(":lynse-newview-protocol").projectDir = file("../lynse-hardware-sdk/first-device/newview/android")
include(":lynse-xyrix-protocol")
project(":lynse-xyrix-protocol").projectDir = file("../lynse-hardware-sdk/first-device/xyrix/android")
include(":lynse-vendor-catalog")
project(":lynse-vendor-catalog").projectDir = file("../lynse-hardware-sdk/catalog/android")
include(":lynse-hardware-bridge")
project(":lynse-hardware-bridge").projectDir = file("../lynse-hardware-sdk/bridge/android")

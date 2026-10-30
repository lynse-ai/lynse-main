import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
//    id("kotlinx-serialization")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.lynseai.dting"
    compileSdk = flutter.compileSdkVersion
   // compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }


    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lynseai.dting"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        //minSdk = flutter.minSdkVersion
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = keystoreProperties["releaseStoreFile"]?.let { file(it) }
            storePassword = keystoreProperties["releaseStorePassword"] as? String
            keyAlias = keystoreProperties["releaseKeyAlias"] as? String
            keyPassword = keystoreProperties["releaseKeyPassword"] as? String
        }
        create("development") {
            storeFile = keystoreProperties["debugStoreFile"]?.let { file(it) }
            storePassword = keystoreProperties["debugStorePassword"] as? String
            keyAlias = keystoreProperties["debugKeyAlias"] as? String
            keyPassword = keystoreProperties["debugKeyPassword"] as? String
        }
    }

    buildTypes {
        release {
            proguardFiles.add(file("proguard-rules/proguard-rules.pro"))
            signingConfig = signingConfigs.getByName("release")
            // 禁用 Deferred Components
        }
        debug {
            // key.properties 是各开发机本地文件（被 android/.gitignore 忽略），
            // 缺它时 development.storeFile 为 null，要到 :app:packageDebug
            // 才炸。调试包没有必须使用自有密钥的理由——缺失就回退默认调试签。
            val development = signingConfigs.findByName("development")
            signingConfig = if (development?.storeFile != null) {
                development
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
//    implementation(files("libs/NvEasyBle-v1.0.8_0507.aar"))    // v1.2.0：v1.1.3 的 init 根本没有 appKey 形参，类里也不含 "*APP#appkey#"
    // 字符串——它没法给需要鉴权的新固件握手，所以必须跟厂商 Demo 同版本。
    //
    // ⚠️ _minSdk36 这份是厂商 v1.2.0 的**元数据改写版**：原包
    // aar-metadata.properties 写 minCompileSdk=37，而本机只有 android-36、
    // AGP 8.13.2 也只支持到 36，直接依赖会被 checkDebugAarMetadata 拦掉。
    // 改写只动了那一行（classes.jar 逐字节相同、jni 齐全），不含任何 API 差异。
    // 它只是联调用的临时物：装机验证完就要换回厂商原包（或升到 compileSdk 37）。
    implementation(files("libs/NvEasyBle-v1.2.0_minSdk36.aar"))
    implementation(files("libs/NvEasyAudio-v1.0.3.aar"))
//    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.0")
    
    // MMKV - 腾讯高性能键值存储库
    implementation("com.tencent:mmkv:1.3.5")
    
    // Kotlin序列化库
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    
    // Kotlin协程库 - 支持异步日志处理
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")

    // LYNSE Hardware SDK：桥接 + 厂商 catalog（MainActivity 手工组装）
    implementation(project(":lynse-hardware-bridge"))
    implementation(project(":lynse-vendor-catalog"))
}

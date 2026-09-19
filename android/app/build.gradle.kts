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
            signingConfig = signingConfigs.getByName("development")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
//    implementation(files("libs/NvEasyBle-v1.0.8_0507.aar"))
    implementation(files("libs/NvEasyBle-v1.1.3.aar"))
    implementation(files("libs/NvEasyAudio-v1.0.2.aar"))
//    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.0")
    
    // MMKV - 腾讯高性能键值存储库
    implementation("com.tencent:mmkv:1.3.5")
    
    // Kotlin序列化库
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    
    // Kotlin协程库 - 支持异步日志处理
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
}

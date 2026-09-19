# 保留 Flutter 引擎类
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.engine.FlutterJNI { *; }

# 保留 Play Core 相关类
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.tasks.** { *; }

# 保留 NvEasyBle SDK 类（替换为实际包名）
-keep class com.nveasy.** { *; }

# 保留 MediaMetadataRetriever 使用的类
-keep class android.media.MediaMetadataRetriever { *; }

# 保留枚举类
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 保留资源引用
-keep class **.R$* { *; }

# 保留 JNI 方法签名
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保留 Flutter 插件类
-if class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback
-keep,allowshrinking,allowobfuscation class <1>

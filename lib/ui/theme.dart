/// 助手版 Material3 主题——把 [LColors]/[LType] 映射进 ThemeData。
///
/// 与旧版 lib/styles/theme.dart 的 LynseTheme 并存，Phase 7 切换主入口后
/// 旧主题随旧代码一并退场。
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AssistantTheme {
  static ThemeData light() {
    final scheme = ColorScheme.light(
      primary: LColors.blueDark,
      onPrimary: Colors.white,
      secondary: LColors.blueDark,
      onSecondary: Colors.white,
      surface: LColors.card,
      onSurface: LColors.text,
      surfaceContainerHighest: LColors.sky,
      error: LColors.danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: LColors.canvas,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        bodyMedium: LType.body,
        bodySmall: LType.muted,
        labelSmall: LType.small,
        titleLarge: LType.title,
        titleMedium: LType.heading,
      ),
      appBarTheme: const AppBarTheme(
        // 透明底 + flexibleSpace 上的 LGlassAppBarLayer 才能真正模糊滚过的正文；
        // 给 AppBar 设半透背景色只会叠一层颜色，不参与模糊
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: LColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: LType.title,
      ),
      navigationBarTheme: NavigationBarThemeData(
        // 背景交给外层 LGlass 浮面统一处理，这里必须透明否则挡住模糊结果
        backgroundColor: Colors.transparent,
        indicatorColor: LColors.blue,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStatePropertyAll(
          LType.small.copyWith(fontWeight: FontWeight.w600, color: LColors.muted),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? LColors.blueDark
                : LColors.muted,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: LColors.line, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LColors.text,
        contentTextStyle: LType.body.copyWith(color: LColors.card),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LRadius.button)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LRadius.input),
          borderSide: const BorderSide(color: LColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LRadius.input),
          borderSide: const BorderSide(color: LColors.line),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

/// Lynse 设计系统：lynse-desktop 设计 token 的 Flutter 实现。
///
/// 对照源：lynse-desktop/packages/ui/styles/tokens.css（oklch 值已近似为 sRGB hex）。
/// 亮色 = #fafafa 画布 + indigo #5f67d8 点缀；暗色 = #17181b 画布 + 暖金 #e0b15c。
library;

import 'package:flutter/material.dart';

/// 设计 token（颜色 / 圆角 / 动效时长）
abstract final class LynseColors {
  // ---- 品牌 ----
  static const Color brandLight = Color(0xFF5F67D8); // indigo，仅用于主按钮/激活态/焦点
  static const Color brandDark = Color(0xFFE0B15C); // 暖金

  // ---- 亮色表面 ----
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightForeground = Color(0xFF202023);
  static const Color lightMuted = Color(0xFFF1F1F4);
  static const Color lightMutedForeground = Color(0xFF83838D);
  static const Color lightBorder = Color(0xFFE6E6EC);
  static const Color lightSidebar = Color(0xFFF5F5F6);

  // ---- 暗色表面（层级：canvas < sidebar < card < popover）----
  static const Color darkBackground = Color(0xFF17181B);
  static const Color darkCard = Color(0xFF1E1F23);
  static const Color darkPopover = Color(0xFF232429);
  static const Color darkForeground = Color(0xFFF5F3EE);
  static const Color darkMuted = Color(0xFF2A2B30);
  static const Color darkMutedForeground = Color(0xFF9B9BA4);
  static const Color darkBorder = Color(0xFF33343B);
  static const Color darkSidebar = Color(0xFF0A0B0D);

  // ---- 图表/波形（主 -> 次渐淡）----
  static const List<Color> chartLight = [
    Color(0xFF5F67D8),
    Color(0xFF747BE2),
    Color(0xFF8B91E8),
    Color(0xFFA7ABED),
    Color(0xFFC7C9F3),
  ];
  static const List<Color> chartDark = [
    Color(0xFFE7BC6E),
    Color(0xFFDFAF57),
    Color(0xFFD2A046),
    Color(0xFFBC8C3A),
    Color(0xFFA2762F),
  ];

  // ---- 说话人着色（转写分角色，8 色）----
  static const List<Color> speakers = [
    Color(0xFF5F67D8),
    Color(0xFF0D9488),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF0284C7),
    Color(0xFF059669),
    Color(0xFFDB2777),
  ];

  // ---- feed 分类色 ----
  static const Color feedFlashLight = Color(0xFF7C3AED); // 闪记紫
  static const Color feedFlashDark = Color(0xFFA78BFA);
  static const Color feedTodoLight = Color(0xFF0284C7); // 待办蓝
  static const Color feedTodoDark = Color(0xFF38BDF8);

  // ---- 语义色 ----
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFEAB308);
  static const Color danger = Color(0xFFEF4444);
}

abstract final class LynseRadius {
  /// 基准 10px（对应 --radius: 0.625rem）
  static const double base = 10;
  static final BorderRadius card = BorderRadius.circular(base * 1.4); // xl
  static final BorderRadius button = BorderRadius.circular(base * 0.8); // md
  static final BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(base * 2.2), // 2xl
  );
}

abstract final class LynseMotion {
  /// 默认 out 缓动（--ease-out: cubic-bezier(0.23,1,0.32,1)）
  static const Curve easeOut = Cubic(0.23, 1.0, 0.32, 1.0);

  /// 抽屉/sheet 曲线（--ease-drawer: cubic-bezier(0.32,0.72,0,1)）
  static const Curve easeDrawer = Cubic(0.32, 0.72, 0.0, 1.0);

  static const Duration quick = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration moderate = Duration(milliseconds: 300);
}

/// 一套主题下的语义色集合，页面通过 `context.lynse` 取用，
/// 避免 500+ 处硬编码色值重演。
class LynseSemantic {
  final Color background;
  final Color card;
  final Color foreground;
  final Color muted;
  final Color mutedForeground;
  final Color border;
  final Color brand;
  final Color danger;
  final Color success;
  final List<Color> chart;
  final Color feedFlash;
  final Color feedTodo;

  const LynseSemantic({
    required this.background,
    required this.card,
    required this.foreground,
    required this.muted,
    required this.mutedForeground,
    required this.border,
    required this.brand,
    required this.danger,
    required this.success,
    required this.chart,
    required this.feedFlash,
    required this.feedTodo,
  });

  static const LynseSemantic light = LynseSemantic(
    background: LynseColors.lightBackground,
    card: LynseColors.lightCard,
    foreground: LynseColors.lightForeground,
    muted: LynseColors.lightMuted,
    mutedForeground: LynseColors.lightMutedForeground,
    border: LynseColors.lightBorder,
    brand: LynseColors.brandLight,
    danger: LynseColors.danger,
    success: LynseColors.success,
    chart: LynseColors.chartLight,
    feedFlash: LynseColors.feedFlashLight,
    feedTodo: LynseColors.feedTodoLight,
  );

  static const LynseSemantic dark = LynseSemantic(
    background: LynseColors.darkBackground,
    card: LynseColors.darkCard,
    foreground: LynseColors.darkForeground,
    muted: LynseColors.darkMuted,
    mutedForeground: LynseColors.darkMutedForeground,
    border: LynseColors.darkBorder,
    brand: LynseColors.brandDark,
    danger: LynseColors.danger,
    success: LynseColors.success,
    chart: LynseColors.chartDark,
    feedFlash: LynseColors.feedFlashDark,
    feedTodo: LynseColors.feedTodoDark,
  );
}

class LynseInherited extends InheritedWidget {
  final LynseSemantic semantic;

  const LynseInherited({
    super.key,
    required this.semantic,
    required super.child,
  });

  static LynseSemantic of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LynseInherited>()!.semantic;

  @override
  bool updateShouldNotify(LynseInherited oldWidget) =>
      oldWidget.semantic != semantic;
}

extension LynseContext on BuildContext {
  /// `context.lynse.brand` 等语义色取用
  LynseSemantic get lynse => LynseInherited.of(this);
}

/// 主题构造（GetMaterialApp theme / darkTheme 直接使用）
abstract final class LynseTheme {
  static ThemeData light() => _build(LynseSemantic.light, Brightness.light);

  static ThemeData dark() => _build(LynseSemantic.dark, Brightness.dark);

  static ThemeData _build(LynseSemantic s, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: s.brand,
      onPrimary: brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF17181B),
      secondary: s.muted,
      onSecondary: s.foreground,
      surface: s.card,
      onSurface: s.foreground,
      error: s.danger,
      onError: Colors.white,
      outlineVariant: s.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'PingFang SC',
      scaffoldBackgroundColor: s.background,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: s.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: s.foreground,
        titleTextStyle: TextStyle(
          fontFamily: 'PingFang SC',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: s.foreground,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: s.brand,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: LynseRadius.button),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: s.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: LynseRadius.card,
          side: BorderSide(color: s.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: s.border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.card,
        hintStyle: TextStyle(color: s.mutedForeground, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: LynseRadius.button,
          borderSide: BorderSide(color: s.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: LynseRadius.button,
          borderSide: BorderSide(color: s.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: LynseRadius.button,
          borderSide: BorderSide(color: s.brand, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? colorScheme.onPrimary : s.mutedForeground),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? s.brand : s.border),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: s.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: LynseRadius.sheet),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: s.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: LynseRadius.card),
      ),
    );
  }
}

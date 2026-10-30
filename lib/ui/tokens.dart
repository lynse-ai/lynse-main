/// Lynse 助手版设计 tokens——复刻 OpenMUSE（CopilotKit, MIT）的设计系统。
///
/// 色板与其 ui.tsx 的 colors 一一对应；圆角、字号、间距按其 StyleSheet
/// 数值换算为 Flutter 逻辑像素。文案层全中文，视觉层保持原版基因：
/// 浅色画布 + 柔和粉彩卡片 + 大圆角 + 小号大写标签。
library;

import 'package:flutter/material.dart';

/// 色板（与 OpenMUSE ui.tsx colors 对齐）
abstract final class LColors {
  /// 页面画布
  static const canvas = Color(0xFFFCFCFC);

  /// 卡片底色
  static const card = Color(0xFFFFFFFF);

  /// 主文字
  static const text = Color(0xFF11191C);

  /// 次要文字
  static const muted = Color(0xFF697176);

  /// 分割线 / 描边
  static const line = Color(0xFFEEEEF0);

  /// 品牌蓝（主按钮底、强调块）
  static const blue = Color(0xFFC8E7FF);

  /// 品牌深蓝（蓝底上的文字/图标）
  static const blueDark = Color(0xFF1473C8);

  /// 天空浅蓝（iconBox 底色、浅强调）
  static const sky = Color(0xFFEDF7FD);

  /// 淡绿（成功态卡片底）
  static const green = Color(0xFFE3F3E8);

  /// 淡紫（中性强调卡片底）
  static const lavender = Color(0xFFF0EEFA);

  /// 淡橙（警示/进行中卡片底）
  static const orange = Color(0xFFFDF0DF);

  /// 危险色（错误文字/图标）
  static const danger = Color(0xFFAA4A45);

  /// 错误底
  static const dangerBg = Color(0xFFFBEFED);

  /// 次按钮底
  static const secondary = Color(0xFFF1F2F3);

  /// 弹层遮罩
  static const modalShade = Color(0x4023302C);
}

/// 圆角（OpenMUSE：卡片 23、sheet 26、输入框 19、按钮 24、chip 20、iconBox 13、错误条 14）
abstract final class LRadius {
  static const card = 23.0;
  static const sheet = 26.0;
  static const input = 19.0;
  static const button = 24.0;
  static const chip = 20.0;
  static const iconBox = 13.0;
  static const error = 14.0;
}

/// 间距基准（4 的倍数；卡片内边距 20、卡片间距 25 对齐原版）
abstract final class LSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 25.0;
  static const xxl = 32.0;
}

/// 字号（fontSize/lineHeight 与 OpenMUSE StyleSheet 对齐）
abstract final class LType {  /// 正文 15/23
  static const body = TextStyle(fontSize: 15, height: 23 / 15, color: LColors.text);

  /// 次要 14/21
  static const muted = TextStyle(fontSize: 14, height: 21 / 14, color: LColors.muted);

  /// 小字 11/17
  static const small = TextStyle(fontSize: 11, height: 17 / 11, color: LColors.muted);

  /// 小号大写标签 10 / 加粗 / 宽字距
  static const label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: LColors.muted,
  );

  /// 页面标题 23 / w600 / 收紧字距
  static const title = TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.7,
    color: LColors.text,
  );

  /// 区块标题 16 / w600
  static const heading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    color: LColors.text,
  );
}

/// 局部毛玻璃参数。
///
/// 只在**浮层**上用（顶栏、底部导航、常驻输入条、sheet），内容卡片保持实色：
/// 一则是 iOS 的实际做法，二则 BackdropFilter 在 Android 上很贵，滚动列表里
/// 每张卡挂 blur 会掉帧。
///
/// 填充一律用带 alpha 的 ARGB 常量而不是 `color.withOpacity()`——后者在
/// Flutter 3.27+ 已废弃，且常量写法不受 SDK 版本影响。
abstract final class LGlassTokens {
  /// 浮层填充：白 62%
  static const fill = Color(0x9EFFFFFF);

  /// 悬浮 dock 用：白 26%。
  ///
  /// dock 要的是「透明」而不是「白卡片」，层次交给模糊和投影撑，
  /// 填充压到 26% 才能让身后光斑真的透出来。
  static const fillFloating = Color(0x42FFFFFF);

  /// dock 的模糊半径：填充变薄后必须加大 blur，否则身后内容会直接看穿文字
  static const dockBlurSigma = 26.0;

  /// 文字密度高的浮层填充：白 78%（sheet、输入条这类要保证对比度的地方）
  static const fillStrong = Color(0xC7FFFFFF);

  /// 玻璃高光描边：白 60%
  static const border = Color(0x99FFFFFF);

  /// 模糊半径：太小看不出玻璃，太大糊成一片。18 是这两者的中间值
  static const blurSigma = 18.0;

  /// 背景光斑色。
  ///
  /// 刻意比 `LColors` 的粉彩填充**更饱和**：玻璃只能透出「和自身底色不同的东西」，
  /// 拿 `#C8E7FF` 这种接近白的粉彩当背景，半透 + 模糊之后和实色毫无区别——
  /// 这正是之前整屏「没有毛玻璃感」的根因，缺的不是 blur，是可透的背景内容。
  static const blobBlue = Color(0xFF8EC5F2);
  static const blobLavender = Color(0xFFBCA9EF);
  static const blobGreen = Color(0xFF9BDCC0);
  static const blobOrange = Color(0xFFF7CE93);
}

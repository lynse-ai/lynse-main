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
abstract final class LType {
  /// 正文 15/23
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

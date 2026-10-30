/// 局部毛玻璃层：背景光斑 + 玻璃浮面。
///
/// 为什么需要两个文件级概念而不只是一个 `LGlass`：
/// 毛玻璃的观感 100% 来自「表面后面有内容被透过来并模糊掉」。本项目的
/// `scaffoldBackgroundColor` 是纯色 `#FCFCFC`，在纯色底上无论怎么加 alpha 和
/// blur，结果都等于那块纯色——所以 [LGlassBackdrop] 不是装饰，是 [LGlass]
/// 能被看见的前提，两者必须成对使用。
///
/// 使用约定：只有**浮层**（顶栏、底部导航与常驻输入条、sheet）走玻璃，
/// 内容卡片继续用实色 `LCard`。
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// 页面背景层：几团固定的柔光色斑，不随内容滚动。
///
/// 用法是把原本放在 `Scaffold.body` 的内容包进来，让上层内容从色斑上滚过，
/// 玻璃浮层才有东西可折射。
class LGlassBackdrop extends StatelessWidget {
  const LGlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: LColors.canvas),
        Positioned(top: -150, left: -120, child: const _Blob(LGlassTokens.blobBlue, 400)),
        Positioned(top: 40, right: -170, child: const _Blob(LGlassTokens.blobLavender, 440)),
        Positioned(bottom: -140, left: -90, child: const _Blob(LGlassTokens.blobGreen, 480)),
        Positioned(bottom: 90, right: -140, child: const _Blob(LGlassTokens.blobOrange, 360)),
        child,
      ],
    );
  }
}

/// 单团柔光：径向渐变从色心淡出到透明，边缘不留硬边。
class _Blob extends StatelessWidget {
  const _Blob(this.color, this.size);

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0)],
              stops: const [0.0, 0.72],
            ),
          ),
        ),
      ),
    );
  }
}

/// 玻璃浮面：模糊身后内容 + 半透填充 + 高光描边。
///
/// [strong] 用于文字密度高的浮层（sheet、输入条），填充更实以保证对比度；
/// 纯装饰性的层用默认的 62% 白，玻璃感更强。
class LGlass extends StatelessWidget {
  const LGlass({
    super.key,
    required this.child,
    this.radius = LRadius.card,
    this.borderRadius,
    this.padding,
    this.strong = false,
    this.floating = false,
    this.shadow = false,
    this.blurSigma,
  });

  final Widget child;
  final double radius;

  /// 需要非均匀圆角时用这个（bottom sheet 只圆上面两角），给了就忽略 [radius]
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  /// true 时填充更实（78% 白），给文字密度高的浮层保对比度
  final bool strong;

  /// 悬浮 dock 档：填充压到 26% 白并自动加大 blur，追求「透明」而非「白卡片」
  final bool floating;

  /// 投影：悬浮件必须有影，否则和贴底的卡片分不出层次
  final bool shadow;

  /// 不传则按 [floating]/[strong] 取默认值
  final double? blurSigma;

  @override
  Widget build(BuildContext context) {
    final rounded = borderRadius ?? BorderRadius.circular(radius);
    final sigma = blurSigma ??
        (floating ? LGlassTokens.dockBlurSigma : LGlassTokens.blurSigma);
    final fill = floating
        ? LGlassTokens.fillFloating
        : (strong ? LGlassTokens.fillStrong : LGlassTokens.fill);
    // ClipRRect 不可省：BackdropFilter 会把整个无限画布采样进来，
    // 不做裁剪时模糊区会溢出圆角之外，并在 Android 上明显掉帧
    final glass = ClipRRect(
      borderRadius: rounded,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: rounded,
            border: Border.all(color: LGlassTokens.border),
          ),
          child: child,
        ),
      ),
    );
    if (!shadow) return glass;
    // 投影必须画在 ClipRRect 外面：被裁剪的子组件无法向外描边
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: rounded,
        boxShadow: const [
          BoxShadow(
            color: Color(0x2623302C),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: glass,
    );
  }
}

/// 贴在 AppBar 的 `flexibleSpace` 上用的玻璃层。
///
/// 必须走 flexibleSpace 而不是 `AppBar(backgroundColor: 半透)`：AppBar 自己的
/// 背景色不参与模糊，只有 flexibleSpace 这一层能采到从下面滚过去的正文。
/// 配套要求 `appBarTheme.backgroundColor` 为透明。
class LGlassAppBarLayer extends StatelessWidget {
  const LGlassAppBarLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = (media.padding.top) + kToolbarHeight;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: LGlassTokens.blurSigma,
          sigmaY: LGlassTokens.blurSigma,
        ),
        child: Container(
          height: height,
          width: double.infinity,
          color: LGlassTokens.fill,
        ),
      ),
    );
  }
}

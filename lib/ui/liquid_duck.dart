/// 悬浮液态玻璃鸭子：可拖动，点一下进助手会话。
///
/// 两个玻璃包各管一层，刻意不叠：
/// - 内芯用 `liquid_glass_renderer` 的 [LiquidGlass]，走 fragment shader 做真折射，
///   这是「液态玻璃」观感的来源；
/// - 外圈用 `glass_kit` 的 [GlassContainer]，只出半透渐变 + 描边 + 投影，
///   **关掉它的 isFrostedGlass**。
///
/// 为什么不叠 blur：glass_kit 的 frosted 模式自己会做一次 BackdropFilter，
/// 和 LiquidGlass 的 shader 叠在同一块屏幕上就是两次全画面采样，
/// 中低端机直接掉帧，而且两层模糊会把折射细节糊平，反而更不像玻璃。
library;

import 'package:flutter/material.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// 悬浮鸭子气泡。必须放在 [Stack] 里作为直接子节点（内部返回 Positioned）。
class LDuckBubble extends StatefulWidget {
  const LDuckBubble({
    super.key,
    required this.onTap,
    this.size = 60,
    this.initialBottomGap = 200,
    this.initialRightGap = 18,
  });

  final VoidCallback onTap;

  /// 内芯直径（不含外圈玻璃环）
  final double size;

  /// 首次布局时距底部 / 右侧的间距
  final double initialBottomGap;
  final double initialRightGap;

  @override
  State<LDuckBubble> createState() => _LDuckBubbleState();
}

class _LDuckBubbleState extends State<LDuckBubble> {
  /// null 表示还没被拖过，用右下角默认位；拖过之后完全由这个值决定
  Offset? _origin;

  double get _outerSize => widget.size + 14;

  Offset _defaultOrigin(Size screen) => Offset(
        screen.width - _outerSize - widget.initialRightGap,
        screen.height - _outerSize - widget.initialBottomGap,
      );

  /// 限制在屏幕内，留一点边距，避免拖出后够不到
  Offset _clamp(Offset p, Size screen) {
    final insets = MediaQuery.of(context).padding;
    final maxX = screen.width - _outerSize - 4;
    final maxY = screen.height - _outerSize - insets.bottom - 4;
    return Offset(
      p.dx.clamp(4.0, maxX < 4 ? 4.0 : maxX),
      p.dy.clamp(insets.top + 4, maxY < insets.top ? insets.top : maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final origin = _clamp(_origin ?? _defaultOrigin(screen), screen);

    return Positioned(
      left: origin.dx,
      top: origin.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onPanUpdate: (d) => setState(() {
          _origin = _clamp(( _origin ?? _defaultOrigin(screen)) + d.delta, screen);
        }),
        child: SizedBox(
          width: _outerSize,
          height: _outerSize,
          child: Center(
            // 外圈：glass_kit 只出渐变/描边/投影，不开 frosted，避免二次 blur
            child: GlassContainer(
              width: _outerSize,
              height: _outerSize,
              shape: BoxShape.circle,
              color: const Color(0x2EFFFFFF),
              borderColor: const Color(0x66FFFFFF),
              borderWidth: 1.2,
              isFrostedGlass: false,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3323302C),
                  blurRadius: 26,
                  offset: Offset(0, 10),
                ),
              ],
              padding: const EdgeInsets.all(7),
              child: _core(),
            ),
          ),
        ),
      ),
    );
  }

  /// 内芯：真液态玻璃。withOwnLayer 直接吃 settings，
  /// 不需要在祖先挂 LiquidGlassRenderScope 提供 settings。
  Widget _core() {
    return LiquidGlass.withOwnLayer(
      shape: const LiquidOval(),
      glassContainsChild: true,
      settings: const LiquidGlassSettings(
        thickness: 22,
        blur: 6,
        refractiveIndex: 1.5,
        chromaticAberration: 0.02,
        lightIntensity: 0.6,
        saturation: 1.6,
        glassColor: Color(0x26FFFFFF),
      ),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: Text('🦆', style: TextStyle(fontSize: widget.size * 0.44)),
        ),
      ),
    );
  }
}

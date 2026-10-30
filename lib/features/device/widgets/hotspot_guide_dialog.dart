import 'dart:async';

import 'package:dting/core/hardware/sdk/wifi_hotspot.dart';
import 'package:dting/ui/components.dart';
import 'package:dting/ui/tokens.dart';
import 'package:flutter/material.dart';

/// 快传前的热点引导弹窗。
///
/// Android 10+ 不允许 App 把手机从「有互联网的健康 WiFi」静默切到设备热点
/// （`WifiNetworkSuggestion` 不保证切换、`WifiNetworkSpecifier` 要用户点系统框、
/// `addNetwork` 已被封），厂商 demo 也是手动连。所以这里只做**一次点击**的引导：
/// 弹窗 → 打开系统 WLAN → 用户点热点 → 我们轮询到「已在设备热点上」就自动关闭，
/// 后面的 TCP 由 SDK 自己接上（它本来就会重试 10 分钟）。
class HotspotGuideDialog extends StatefulWidget {
  const HotspotGuideDialog({super.key, required this.hotspotName});

  final String hotspotName;

  @override
  State<HotspotGuideDialog> createState() => _HotspotGuideDialogState();
}

class _HotspotGuideDialogState extends State<HotspotGuideDialog> {
  Timer? _poll;
  bool _waiting = true;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!mounted) return;
      if (await WifiHotspot.isOnDeviceAccessPoint()) {
        _poll?.cancel();
        if (mounted) Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: LCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '连接卡片热点',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: LColors.text,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '快传要先把手机连到卡片自己的热点：',
              style: TextStyle(fontSize: 13, color: LColors.muted),
            ),
            const SizedBox(height: 6),
            SelectableText(
              widget.hotspotName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: LColors.text,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: LColors.blueDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _waiting ? '连上后会自动开始，不用再点' : '已连上',
                    style: TextStyle(fontSize: 12, color: LColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LButton(
                  label: '取消',
                  small: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 10),
                LButton(
                  label: '去连接',
                  small: true,
                  onPressed: () async {
                    setState(() => _waiting = true);
                    await WifiHotspot.openWifiPanel();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 打开引导弹窗；返回是否已在设备热点上（false = 用户取消）。
Future<bool> showHotspotGuideDialog(
  BuildContext context, {
  required String hotspotName,
}) async {
  if (await WifiHotspot.isOnDeviceAccessPoint()) return true;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => HotspotGuideDialog(hotspotName: hotspotName),
  );
  return result ?? false;
}

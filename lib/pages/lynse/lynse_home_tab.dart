/// 主页 tab：问候头 + 今日摘要 + 最近导入 feed + 录音胶囊
/// （对照 lynse-desktop home/page.tsx 与 docs/design/home-wireframe.html）。
library;

import 'package:dting/controller/device_session_controller.dart';
import 'package:dting/hardware/hardware_kit.dart';
import 'package:dting/pages/lynse/lynse_widgets.dart';
import 'package:dting/styles/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LynseHomeTab extends StatefulWidget {
  const LynseHomeTab({super.key});

  @override
  State<LynseHomeTab> createState() => _LynseHomeTabState();
}

class _LynseHomeTabState extends State<LynseHomeTab> {
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  String get _dateLabel {
    final now = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '${now.month}月${now.day}日 星期${weekdays[now.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.lynse;
    final c = DeviceSessionController.instance;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            // ---- 问候头 ----
            Text(
              _greeting,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: s.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _dateLabel,
              style: TextStyle(fontSize: 13, color: s.mutedForeground),
            ),
            const SizedBox(height: 16),

            // ---- 今日摘要卡 ----
            LynseCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusPill(
                        label: c.connectionPhase.value.isUsable
                            ? '设备已连接'
                            : '设备未连接',
                        color: c.connectionPhase.value.isUsable
                            ? LynseColors.success
                            : s.mutedForeground,
                      ),
                      const Spacer(),
                      Obx(() => Text(
                            c.connectedDevice.value?.name ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: s.mutedForeground,
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Obx(() => Text(
                        c.recordState.value == RecordState.recording
                            ? '正在${c.recordScene.value == RecordScene.call ? '通话' : '会议'}录音…'
                            : '点下方红色按钮开始硬件录音',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: s.foreground,
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---- 最近记录 feed ----
            SectionHeader(title: '最近记录'),
            const SizedBox(height: 8),
            Obx(() {
              final imported = c.lastImported.value;
              if (imported == null) {
                return LynseCard(
                  child: LynseEmpty(
                    icon: Icons.graphic_eq_outlined,
                    title: '还没有录音',
                    subtitle: '连接设备后开始第一次录音吧',
                  ),
                );
              }
              return Column(
                children: [
                  LynseCard(
                    onTap: () => Get.toNamed('/lynseRecordingDetail',
                        arguments: {'title': _importTitle(imported)}),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: s.brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.graphic_eq,
                              size: 18, color: s.brand),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _importTitle(imported),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: s.foreground,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                imported.filePath.split('/').last,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: s.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 18, color: s.mutedForeground),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),

        // ---- 底部录音胶囊（灵动岛式，对齐桌面端 sticky capsule）----
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            // 注意：Rx 读取必须发生在 Obx 回调内，否则 GetX 抛 improper use
            child: Obx(() => _buildRecordCapsule(context)),
          ),
        ),
      ],
    );
  }

  String _importTitle(ImportedRecording r) {
    if (r.recordStartTime != null) {
      return '${r.recordStartTime!.month}月${r.recordStartTime!.day}日'
          '${r.scene == RecordScene.call ? '通话' : '会议'}录音';
    }
    return r.filePath.split('/').last;
  }

  Widget _buildRecordCapsule(BuildContext context) {
    final s = context.lynse;
    final c = DeviceSessionController.instance;
    final recording = c.recordState.value == RecordState.recording;
    final connected = c.connectionPhase.value.isUsable;
    return AnimatedContainer(
      duration: LynseMotion.moderate,
      curve: LynseMotion.easeOut,
      padding: recording
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: recording ? s.card : LynseColors.danger,
        borderRadius: BorderRadius.circular(999),
        border: recording ? Border.all(color: s.border) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => _toggle(c, recording, connected),
        child: recording
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stop, color: LynseColors.danger),
                  const SizedBox(width: 8),
                  Text(
                    '停止录音',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: s.foreground,
                    ),
                  ),
                ],
              )
            : Container(
                width: 52,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.mic, color: Colors.white),
              ),
      ),
    );
  }

  void _toggle(DeviceSessionController c, bool recording, bool connected) {
    if (!connected) {
      Get.snackbar('提示', '请先在「设备」页连接录音硬件');
      return;
    }
    if (recording) {
      c.stopRecording();
    } else {
      c.startRecording(RecordScene.meeting);
    }
  }
}

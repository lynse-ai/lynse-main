/// 今日屏：助手版首页（对标 OpenMUSE TodayScreen）。
///
/// 结构：问候主卡（设备状态 + 主行动）→ 三格统计 → 设备卡 → 最近录音 →
/// 行动项。录音/任务/行动项数据源在 Phase 3/5/6 接入，当前为占位空态。
library;

import 'package:dting/core/hardware/hardware_kit.dart';
import 'package:dting/core/services/device_session_controller.dart';
import 'package:dting/core/services/recording_library.dart';
import 'package:dting/router/modules/assistant_router.dart';
import 'package:dting/ui/components.dart';
import 'package:dting/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return '夜深了';
    if (hour < 11) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  @override
  Widget build(BuildContext context) {
    final session = DeviceSessionController.instance;
    return Obx(() {
      final device = session.connectedDevice.value;
      final battery = session.battery.value;
      final phase = session.connectionPhase.value;
      final connected = device != null && phase.isUsable;

      return ListView(
        padding: const EdgeInsets.all(LSpacing.xl),
        children: [
          _HeroCard(
            greeting: _greeting(),
            connected: connected,
            deviceName: device?.name,
            batteryPercent: battery?.levelPercent,
          ),
          const SizedBox(height: LSpacing.xl),
          const _StatRow(),
          const SizedBox(height: LSpacing.xl),
          const LSectionHeading(label: '设备'),
          const SizedBox(height: 12),
          _DeviceCard(
            connected: connected,
            deviceName: device?.name,
            phase: phase,
            batteryPercent: battery?.levelPercent,
          ),
          const SizedBox(height: LSpacing.xl),
          const LSectionHeading(label: '最近录音'),
          const SizedBox(height: 12),
          const LCard(
            child: LEmpty(
              icon: Icons.graphic_eq,
              title: '还没有录音',
              message: '连接设备后下载的录音会出现在这里',
            ),
          ),
          const SizedBox(height: LSpacing.xl),
          const LSectionHeading(label: '行动项'),
          const SizedBox(height: 12),
          const LCard(
            child: LEmpty(
              icon: Icons.checklist,
              title: '暂无待办',
              message: '录音转写后助手会自动提取行动项',
            ),
          ),
          const SizedBox(height: LSpacing.xl),
        ],
      );
    });
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.greeting,
    required this.connected,
    this.deviceName,
    this.batteryPercent,
  });

  final String greeting;
  final bool connected;
  final String? deviceName;
  final int? batteryPercent;

  @override
  Widget build(BuildContext context) {
    final subtitle = connected
        ? (batteryPercent != null
              ? '$deviceName 已连接 · 电量 $batteryPercent%'
              : '$deviceName 已连接')
        : '设备未连接。连接录音笔，让今天的每一场对话都被记住。';

    return Container(
      padding: const EdgeInsets.all(LSpacing.xxl),
      decoration: BoxDecoration(
        color: LColors.blue,
        borderRadius: BorderRadius.circular(LRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 13, color: LColors.blueDark),
              const SizedBox(width: 7),
              Text(
                '每天一点从容',
                style: LType.label.copyWith(color: LColors.blueDark),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            '$greeting，\n今天也留一点呼吸感。',
            style: const TextStyle(
              fontSize: 29,
              height: 36 / 29,
              letterSpacing: -1.7,
              fontWeight: FontWeight.w500,
              color: LColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(subtitle, style: LType.muted.copyWith(color: const Color(0xFF617680))),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: LButton(
              label: '总结今天的录音',
              icon: Icons.auto_awesome,
              primary: true,
              onPressed: () => Get.toNamed(AssistantRouter.chat),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow();

  @override
  Widget build(BuildContext context) {
    final library = RecordingLibrary.instance;
    return Obx(() {
      final total = library.recordings.length;
      final today = library.todayCount.value;
      return Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.graphic_eq,
              label: '录音',
              value: total > 0 ? '$total' : '—',
              sub: today > 0 ? '今天 +$today' : null,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: _StatCard(icon: Icons.task_alt, label: '待办', value: '—')),
          const SizedBox(width: 10),
          const Expanded(child: _StatCard(icon: Icons.sync, label: '进行中', value: '—')),
        ],
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, this.sub});

  final IconData icon;
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return LCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: LColors.blueDark),
          const SizedBox(height: 8),
          Text(value, style: LType.heading),
          const SizedBox(height: 2),
          Text(sub ?? label, style: LType.small),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.connected,
    this.deviceName,
    required this.phase,
    this.batteryPercent,
  });

  final bool connected;
  final String? deviceName;
  final ConnectionPhase phase;
  final int? batteryPercent;

  @override
  Widget build(BuildContext context) {
    if (!connected) {
      return LCard(
        child: Column(
          children: [
            const LEmpty(
              icon: Icons.headphones,
              title: '未连接设备',
              message: '打开录音笔，到「设备」页扫描连接',
            ),
          ],
        ),
      );
    }
    return LCard(
      child: LLinkRow(
        icon: Icons.headphones,
        title: deviceName ?? '录音设备',
        subtitle: batteryPercent != null ? '已连接 · 电量 $batteryPercent%' : '已连接',
        onTap: () {
          // 切到设备 tab 由 shell 层处理；这里先进入会话提供设备问答
          Get.toNamed(AssistantRouter.chat);
        },
      ),
    );
  }
}

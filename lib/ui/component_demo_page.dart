/// 组件库 demo 页——设计系统 1:1 复刻验收用。
library;

import 'package:flutter/material.dart';
import 'package:dting/ui/components.dart';
import 'package:dting/ui/tokens.dart';

class ComponentDemoPage extends StatelessWidget {
  const ComponentDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设计系统 Demo')),
      body: ListView(
        padding: const EdgeInsets.all(LSpacing.xl),
        children: const [
          _Section(
            label: 'Mascot / 色板',
            child: _MascotShowcase(),
          ),
          SizedBox(height: LSpacing.xl),
          _Section(
            label: 'Button / IconButton',
            child: _ButtonShowcase(),
          ),
          SizedBox(height: LSpacing.xl),
          _Section(label: 'Card / Chip / 状态色', child: _CardShowcase()),
          SizedBox(height: LSpacing.xl),
          _Section(label: '列表行 / 空态 / 错误条', child: _RowsShowcase()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LSectionHeading(label: label),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _MascotShowcase extends StatelessWidget {
  const _MascotShowcase();

  @override
  Widget build(BuildContext context) {
    return const LCard(
      child: Row(
        children: [
          LMascot(size: 64),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今天也要加油', style: LType.heading),
                SizedBox(height: 4),
                Text('画布 #FCFCFC · 天空 #EDF7FD · 蓝 #C8E7FF', style: LType.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonShowcase extends StatelessWidget {
  const _ButtonShowcase();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            LButton(label: '规划今天', icon: Icons.auto_awesome, primary: true),
            LButton(label: '次按钮'),
            LButton(label: '小按钮', small: true),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            LIconButton(icon: Icons.headphones),
            SizedBox(width: 10),
            LIconButton(icon: Icons.graphic_eq),
            SizedBox(width: 10),
            LIconButton(icon: Icons.download, tint: LColors.green),
          ],
        ),
      ],
    );
  }
}

class _CardShowcase extends StatelessWidget {
  const _CardShowcase();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('白卡片 · 圆角 23', style: LType.heading),
                    SizedBox(height: 6),
                    Text('正文 15/23，次要文字 14/21，小字 11/17。', style: LType.muted),
                  ],
                ),
              ),
              LChip(label: 'DEFAULT'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LCard(
          color: LColors.blue,
          child: Text(
            '蓝卡片（问候/主行动）',
            style: LType.heading.copyWith(color: LColors.blueDark),
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: LCard(color: LColors.green, padding: EdgeInsets.all(14), child: Text('成功', style: LType.body))),
            SizedBox(width: 10),
            Expanded(child: LCard(color: LColors.lavender, padding: EdgeInsets.all(14), child: Text('中性', style: LType.body))),
            SizedBox(width: 10),
            Expanded(child: LCard(color: LColors.orange, padding: EdgeInsets.all(14), child: Text('进行中', style: LType.body))),
          ],
        ),
      ],
    );
  }
}

class _RowsShowcase extends StatelessWidget {
  const _RowsShowcase();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LCard(
          child: Column(
            children: [
              LLinkRow(icon: Icons.headphones, title: 'Xyrix 录音笔', subtitle: '已连接 · 电量 80%'),
              Divider(),
              LLinkRow(icon: Icons.graphic_eq, title: '产品周会录音', subtitle: '今天 10:24 · 42 分钟'),
              Divider(),
            ],
          ),
        ),
        LCard(
          child: LCheckRow(label: '整理今天的会议待办', value: true, onChanged: (_) {}),
        ),
        const SizedBox(height: 12),
        const LErrorNotice(message: '转写失败：网络不可用，已保留本地录音'),
      ],
    );
  }
}

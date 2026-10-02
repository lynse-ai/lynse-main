/// 助手会话屏（Phase 6 正式版）：消息流 + 工具卡 + 追问建议 + 会话持久化。
library;

import 'package:dting/core/services/assistant_service.dart';
import 'package:dting/router/modules/assistant_router.dart';
import 'package:dting/ui/components.dart';
import 'package:dting/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AssistantChatPage extends StatefulWidget {
  const AssistantChatPage({super.key});

  @override
  State<AssistantChatPage> createState() => _AssistantChatPageState();
}

class _AssistantChatPageState extends State<AssistantChatPage> {
  final _controller = TextEditingController();
  late final AssistantService _service;

  static const _suggestions = [
    '今日概览',
    '设备电量怎么样',
    '最近的录音',
    '任务进度',
  ];

  @override
  void initState() {
    super.initState();
    _service = AssistantService.instance;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _service.thinking.value) return;
    _controller.clear();
    _service.send(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('助手'),
        actions: [
          IconButton(
            tooltip: '新会话',
            icon: const Icon(Icons.add_comment_outlined, size: 20, color: LColors.muted),
            onPressed: () => _service.newSession(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              final msgs = _service.messages;
              if (msgs.isEmpty) return _buildWelcome();
              return ListView.builder(
                padding: const EdgeInsets.all(LSpacing.xl),
                itemCount: msgs.length + (_service.thinking.value ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == msgs.length) {
                    return const _ThinkingBubble();
                  }
                  return _MessageBubble(message: msgs[i], onJumpRecording: _jumpRecording);
                },
              );
            }),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  void _jumpRecording(String fileName) {
    Get.back<void>(); // 回到 shell
    Get.toNamed(AssistantRouter.recordingDetail, arguments: {
      'title': fileName,
      'localPath': null,
    });
  }

  Widget _buildWelcome() {
    return Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(LSpacing.xxl),
        children: [
          const LMascot(size: 72),
          const SizedBox(height: LSpacing.md),
          const Text('今天我能帮你什么？', style: LType.title, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text(
            '设备状态 · 录音整理 · 待办提取（后端接通后能力持续升级）',
            style: LType.muted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: LSpacing.xl),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final s in _suggestions)
                LChip(
                  label: s,
                  tint: LColors.sky,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          // 追问建议条（对标 OpenMUSE follow-up queue 的移动端形态）
          Obx(() {
            final showSuggestions =
                _service.messages.isNotEmpty && !_service.thinking.value;
            if (!showSuggestions) return const SizedBox.shrink();
            return SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: LSpacing.xl),
                children: [
                  for (final s in _suggestions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(s, style: LType.small),
                        backgroundColor: LColors.card,
                        side: const BorderSide(color: LColors.line),
                        onPressed: () => _send(s),
                      ),
                    ),
                ],
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(LSpacing.xl, 8, LSpacing.xl, LSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(hintText: '问你的助手…'),
                  ),
                ),
                const SizedBox(width: 10),
                Obx(() => LButton(
                      label: _service.thinking.value ? '…' : '发送',
                      icon: _service.thinking.value ? Icons.hourglass_top : Icons.send,
                      primary: true,
                      onPressed: _service.thinking.value ? null : () => _send(),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LMascot(size: 28),
            SizedBox(width: 8),
            Text('想想看…', style: LType.small),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onJumpRecording});

  final AssistantMessage message;
  final void Function(String fileName) onJumpRecording;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? LColors.blue : LColors.card,
                borderRadius: BorderRadius.circular(LRadius.input),
                border: isUser ? null : Border.all(color: LColors.line),
              ),
              child: Text(message.text, style: LType.body),
            ),
            if (message.toolCard != null) ...[
              const SizedBox(height: 8),
              _ToolCard(card: message.toolCard!, onJumpRecording: onJumpRecording),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.card, required this.onJumpRecording});

  final AssistantToolCard card;
  final void Function(String fileName) onJumpRecording;

  @override
  Widget build(BuildContext context) {
    return switch (card.kind) {
      'device' => _DeviceCard(payload: card.payload),
      'recordings' => _RecordingsCard(payload: card.payload, onJump: onJumpRecording),
      'tasks' => _TasksCard(payload: card.payload),
      _ => const SizedBox.shrink(),
    };
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final connected = payload['connected'] == true;
    return LCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          LIconButton(
            icon: connected ? Icons.headphones : Icons.bluetooth_disabled,
            tint: connected ? LColors.blue : LColors.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payload['name']?.toString() ?? '设备状态',
                    style: LType.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  connected
                      ? '已连接${payload['battery'] != null ? ' · 电量 ${payload['battery']}%' : ''}'
                      : '未连接',
                  style: LType.small,
                ),
              ],
            ),
          ),
          LChip(label: connected ? '在线' : '离线', tint: connected ? LColors.green : LColors.canvas),
        ],
      ),
    );
  }
}

class _RecordingsCard extends StatelessWidget {
  const _RecordingsCard({required this.payload, required this.onJump});

  final Map<String, dynamic> payload;
  final void Function(String fileName) onJump;

  @override
  Widget build(BuildContext context) {
    final items = (payload['items'] as List?) ?? [];
    if (items.isEmpty) {
      return const LCard(
        padding: EdgeInsets.all(14),
        child: Text('暂无录音', style: LType.muted),
      );
    }
    return LCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          for (final item in items)
            () {
              final m = (item as Map).cast<String, dynamic>();
              return LLinkRow(
                icon: Icons.graphic_eq,
                title: m['fileName']?.toString() ?? '',
                subtitle:
                    '${m['date']} · ${m['sizeLabel']} · ${m['sourceLabel']}',
                onTap: () => onJump(m['fileName']?.toString() ?? ''),
              );
            }(),
        ],
      ),
    );
  }
}

class _TasksCard extends StatelessWidget {
  const _TasksCard({required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final items = (payload['items'] as List?) ?? [];
    if (items.isEmpty) {
      return LCard(
        padding: const EdgeInsets.all(14),
        child: Text(
          '录音 ${payload['recordings'] ?? 0} 条 · 今日 +${payload['today'] ?? 0}',
          style: LType.muted,
        ),
      );
    }
    return LCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          for (final item in items)
            () {
              final m = (item as Map).cast<String, dynamic>();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    LChip(label: m['type']?.toString() ?? '', tint: LColors.sky),
                    const SizedBox(width: 10),
                    Expanded(child: Text(m['title']?.toString() ?? '', style: LType.body)),
                    Text('${m['progress']}%', style: LType.small),
                  ],
                ),
              );
            }(),
        ],
      ),
    );
  }
}

/// 助手会话屏（骨架版）：Phase 6 接入 Mock 后端与工具卡片。
///
/// 当前提供：欢迎态 + 输入框（发送后本地回显，Phase 6 替换为
/// AssistantService 的流式应答）。
library;

import 'package:dting/ui/components.dart';
import 'package:dting/ui/tokens.dart';
import 'package:flutter/material.dart';

class AssistantChatPage extends StatefulWidget {
  const AssistantChatPage({super.key});

  @override
  State<AssistantChatPage> createState() => _AssistantChatPageState();
}

class _AssistantChatPageState extends State<AssistantChatPage> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _messages.add(
        _ChatMessage(role: 'assistant', text: '收到，助手大脑还在接线中（Phase 6 接入）。'),
      );
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('助手')),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LMascot(size: 72),
                        SizedBox(height: 16),
                        Text('今天我能帮你什么？', style: LType.title),
                        SizedBox(height: 8),
                        Text('问问设备状态、最近的录音，或让我整理会议待办', style: LType.muted),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(LSpacing.xl),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _MessageBubble(message: _messages[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                LSpacing.xl,
                8,
                LSpacing.xl,
                LSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: '问你的助手…'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  LButton(label: '发送', primary: true, onPressed: _send),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String role; // user | assistant
  final String text;

  const _ChatMessage({required this.role, required this.text});
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: isUser ? LColors.blue : LColors.card,
          borderRadius: BorderRadius.circular(LRadius.input),
          border: isUser ? null : Border.all(color: LColors.line),
        ),
        child: Text(message.text, style: LType.body),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart';
import '../app_theme.dart';
import 'tool_call_card.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final timeStr = DateFormat('h:mm a').format(message.timestamp);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Header: Role & Timestamp
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isUser) ...[
                const CircleAvatar(
                  radius: 10,
                  backgroundColor: AppTheme.primary,
                  child: Icon(Icons.smart_toy_outlined, size: 12, color: Colors.white),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Gemini Agent',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                ),
              ] else ...[
                const Text(
                  'You',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                const SizedBox(width: 6),
                const CircleAvatar(
                  radius: 10,
                  backgroundColor: Color(0xFF475569),
                  child: Icon(Icons.person_outline, size: 12, color: Colors.white),
                ),
              ],
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.35)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // RAG citations if any
          if (message.ragSources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: message.ragSources.map((src) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hub_outlined, size: 11, color: AppTheme.accentCyan),
                        const SizedBox(width: 4),
                        Text(
                          src,
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.accentCyan),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Tool calls logs
          if (message.toolCalls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                children: message.toolCalls.map((t) => ToolCallCard(toolLog: t)).toList(),
              ),
            ),

          // Message Content Body
          if (message.content.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxWidth: 680),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF312E81) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(10),
                  topRight: const Radius.circular(10),
                  bottomLeft: Radius.circular(isUser ? 10 : 2),
                  bottomRight: Radius.circular(isUser ? 2 : 10),
                ),
                border: Border.all(
                  color: isUser ? AppTheme.primary.withOpacity(0.5) : AppTheme.darkBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFFF1F5F9)),
                      code: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        backgroundColor: Color(0xFF0F172A),
                        color: Color(0xFF38BDF8),
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      codeblockPadding: const EdgeInsets.all(10),
                      h1: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      h2: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      h3: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: message.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied message to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, size: 12, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Running / Thinking Indicator
          if (message.isProcessing && message.content.isEmpty && message.toolCalls.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLight),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Agent is thinking & querying codebase...',
                    style: TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

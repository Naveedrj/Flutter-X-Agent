import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/chat_message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';
import 'tool_call_card.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final timeStr = DateFormat('h:mm a').format(message.timestamp);

    // Adversarial styling branches
    if (message.isBlueTeam) {
      return _buildBlueTeamCard(context, timeStr);
    } else if (message.isRedTeam) {
      return _buildRedTeamCard(context, timeStr);
    } else if (message.isConsensus) {
      return _buildConsensusCard(context, timeStr);
    }

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.smart_toy_outlined, size: 13, color: AppTheme.primaryLight),
                      const SizedBox(width: 5),
                      const Text(
                        'Flutter-X-Agent',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      if (message.modelName != null && message.modelName!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(width: 1, height: 10, color: Colors.white24),
                        const SizedBox(width: 6),
                        Text(
                          message.modelName!,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentCyan,
                          ),
                        ),
                      ],
                    ],
                  ),
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
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35)),
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
                      color: AppTheme.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
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
              constraints: const BoxConstraints(maxWidth: 720),
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
                  color: isUser ? AppTheme.primary.withValues(alpha: 0.5) : AppTheme.darkBorder,
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
                            Icon(Icons.copy, size: 12, color: Colors.white.withValues(alpha: 0.3)),
                            const SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Running / Live Execution Step Indicator
          if (message.isProcessing)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF131D30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLight),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    message.statusStep ?? 'Agent is analyzing & implementing...',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlueTeamCard(BuildContext context, String timeStr) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C172E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.7), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, size: 15, color: AppTheme.accentCyan),
                const SizedBox(width: 6),
                Text(
                  '🔵 BLUE TEAM (BUILDER) • ROUND ${message.roundNumber ?? 1}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: AppTheme.accentCyan),
                ),
                const Spacer(),
                if (message.modelName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
                    child: Text(message.modelName!, style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.white70)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.isProcessing)
                  const Row(
                    children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan)),
                      SizedBox(width: 8),
                      Text('Architecting & constructing implementation...', style: TextStyle(fontSize: 12, color: AppTheme.accentCyan)),
                    ],
                  )
                else
                  MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.45),
                      code: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: AppTheme.primaryLight, backgroundColor: Color(0xFF08101E)),
                      codeblockDecoration: BoxDecoration(color: const Color(0xFF08101E), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.darkBorder)),
                    ),
                  ),
                if (message.hardenedCode != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentCyan,
                        side: const BorderSide(color: AppTheme.accentCyan, width: 0.8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 24),
                      ),
                      icon: const Icon(Icons.copy, size: 11),
                      label: const Text('Copy Code', style: TextStyle(fontSize: 10.5)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: message.hardenedCode!));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied to clipboard!'), duration: Duration(seconds: 1)));
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedTeamCard(BuildContext context, String timeStr) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F0F16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.7), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF881337).withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.coronavirus_outlined, size: 15, color: Color(0xFFF87171)),
                const SizedBox(width: 6),
                Text(
                  '🔴 RED TEAM (HACKER) • ROUND ${message.roundNumber ?? 1}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFFF87171)),
                ),
                const Spacer(),
                if (message.modelName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
                    child: Text(message.modelName!, style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.white70)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.vulnerabilities.isNotEmpty || message.optimizations.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (message.vulnerabilities.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.5)),
                          ),
                          child: Text('🚨 ${message.vulnerabilities.length} Exploits Found', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFCA5A5))),
                        ),
                      if (message.optimizations.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                          ),
                          child: Text('⚡ ${message.optimizations.length} Bottlenecks', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (message.isProcessing)
                  const Row(
                    children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF87171))),
                      SizedBox(width: 8),
                      Text('Attacking code & hunting for race conditions...', style: TextStyle(fontSize: 12, color: Color(0xFFF87171))),
                    ],
                  )
                else
                  MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.45),
                      code: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Color(0xFFFCA5A5), backgroundColor: Color(0xFF160A10)),
                      codeblockDecoration: BoxDecoration(color: const Color(0xFF160A10), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.darkBorder)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsensusCard(BuildContext context, String timeStr) {
    final workspace = context.read<WorkspaceProvider>();
    final chat = context.read<ChatProvider>();
    final targetPath = workspace.currentOpenFilePath ?? 'lib/main.dart';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.7), width: 1.2),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: AppTheme.success, size: 20),
              const SizedBox(width: 8),
              const Text('ADVERSARIAL HARDENING COMPLETE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: const Text('100/100 Hardened', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.success)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: message.content,
            styleSheet: MarkdownStyleSheet(p: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (message.hardenedCode != null) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 28),
                  ),
                  icon: const Icon(Icons.save_as_outlined, size: 13),
                  label: Text('Apply to $targetPath', style: const TextStyle(fontSize: 11)),
                  onPressed: () async {
                    final adv = context.read<ChatProvider>().adversarialService;
                    await adv.applyHardenedCode(filePath: targetPath, hardenedCode: message.hardenedCode!);
                    await workspace.refreshFileTree();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hardened code safely applied to $targetPath! (Snapshot taken)'), backgroundColor: AppTheme.success),
                      );
                    }
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.darkBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 28),
                  ),
                  icon: const Icon(Icons.copy, size: 12),
                  label: const Text('Copy Code', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message.hardenedCode!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hardened code copied!'), duration: Duration(seconds: 1)));
                  },
                ),
              ],
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentCyan,
                  side: const BorderSide(color: AppTheme.accentCyan, width: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                ),
                icon: const Icon(Icons.play_arrow_outlined, size: 13),
                label: const Text('xrun flutter test', style: TextStyle(fontSize: 11)),
                onPressed: () => chat.executeXRunCommand('flutter test'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

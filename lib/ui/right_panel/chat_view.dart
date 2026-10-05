import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';
import '../dialogs/settings_dialog.dart';
import 'message_bubble.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<String> _quickPrompts = [
    '🔍 Analyze codebase structure',
    '🐛 Inspect files & find bugs',
    '⚡ List all files & entry points',
    '🧪 Run tests in terminal',
    '📝 Create README.md file',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int _lastMessageCount = 0;
  String? _lastSessionId;

  void _checkAutoScroll(String? sessionId, int currentCount, bool isBusy) {
    if (sessionId != _lastSessionId || currentCount != _lastMessageCount || isBusy) {
      _lastSessionId = sessionId;
      _lastMessageCount = currentCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    _inputController.clear();
    chatProvider.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final workspaceProvider = context.watch<WorkspaceProvider>();

    final session = chatProvider.activeSession;
    final messages = session?.messages ?? [];
    final isBusy = chatProvider.isAgentBusy;

    _checkAutoScroll(session?.id, messages.length, isBusy);

    return Container(
      color: AppTheme.darkBg,
      child: Column(
        children: [
          // Missing API Key Banner
          if (!settingsProvider.hasValidApiKey)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.12),
                border: const Border(bottom: BorderSide(color: AppTheme.warning, width: 1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key_rounded, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Gemini API key is unset (using placeholder).',
                      style: TextStyle(fontSize: 11, color: AppTheme.warning, fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 24),
                      foregroundColor: AppTheme.warning,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const SettingsDialog(),
                      );
                    },
                    child: const Text('Add Key', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Missing Workspace Folder Warning
          if (workspaceProvider.rootPath == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: AppTheme.primary.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppTheme.primaryLight),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'No workspace folder selected. Agent will operate in local directory.',
                      style: TextStyle(fontSize: 11, color: AppTheme.primaryLight),
                    ),
                  ),
                  InkWell(
                    onTap: () => workspaceProvider.pickWorkspaceFolder(),
                    child: const Text(
                      'Select Folder',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),

          // Message List or Welcome State
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.smart_toy_outlined, size: 36, color: AppTheme.primaryLight),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            session?.title ?? 'Gemini Agentic Assistant',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Equipped with RAG codebase search, file read/write/edit/move, and terminal execution.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45)),
                          ),
                          const SizedBox(height: 18),
                          // Quick prompt buttons
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: _quickPrompts.map((p) {
                              return ActionChip(
                                label: Text(p, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                backgroundColor: const Color(0xFF1E293B),
                                side: const BorderSide(color: AppTheme.darkBorder),
                                onPressed: () {
                                  _inputController.text = p;
                                  _sendMessage();
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return MessageBubble(message: msg);
                    },
                  ),
          ),

          // Prompt Input Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF131D30),
              border: Border(top: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.enter, control: false, meta: false, shift: false): _sendMessage,
                          },
                          child: TextField(
                            controller: _inputController,
                            focusNode: _focusNode,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                            decoration: InputDecoration(
                              hintText: isBusy ? 'Agent is working...' : 'Ask agent to inspect, edit, build, or run...',
                              hintStyle: TextStyle(fontSize: 12.5, color: Colors.white.withOpacity(0.35)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              prefixIcon: const Icon(Icons.auto_awesome, size: 18, color: AppTheme.primaryLight),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBusy ? const Color(0xFFDC2626) : AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: Icon(isBusy ? Icons.stop_rounded : Icons.send_rounded, size: 16),
                        label: Text(
                          isBusy ? 'Stop' : 'Send',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: isBusy
                            ? () {
                                chatProvider.stopAgentTask();
                              }
                            : _sendMessage,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Press Enter to send, Shift+Enter for newline',
                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3)),
                    ),
                    if (session != null && session.messages.isNotEmpty)
                      InkWell(
                        onTap: () => chatProvider.clearActiveSessionMessages(),
                        child: Text(
                          'Clear Chat',
                          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

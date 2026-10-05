import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/llm_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';
import '../dialogs/git_commit_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../right_panel/message_bubble.dart';
import 'terminal_console_view.dart';

class AgentChatTerminalView extends StatefulWidget {
  const AgentChatTerminalView({super.key});

  @override
  State<AgentChatTerminalView> createState() => _AgentChatTerminalViewState();
}

class _AgentChatTerminalViewState extends State<AgentChatTerminalView> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _showLiveTerminalDrawer = false;
  bool _isXRunDetected = false;

  final List<String> _quickActionChips = [
    '🛡️ Auto-Debug & Fix Tests',
    '🔀 AI Commit & Push',
    'xrun flutter test',
    'xrun flutter pub get',
    'xrun git status',
    'xrun ls -la',
    '🔍 Analyze codebase architecture',
    '📝 Create README.md',
  ];

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() {
      final text = _inputController.text.trim().toLowerCase();
      final isXRun = text.startsWith('xrun') || text.startsWith('!run');
      if (isXRun != _isXRunDetected) {
        setState(() => _isXRunDetected = isXRun);
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
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

  void _triggerAutoDebug() {
    final chatProvider = context.read<ChatProvider>();
    final workspace = context.read<WorkspaceProvider>();

    if (workspace.rootPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a workspace folder first')),
      );
      return;
    }

    chatProvider.runAutoDebug('flutter test');
    _scrollToBottom();
  }

  void _openGitCommitDialog() {
    final workspace = context.read<WorkspaceProvider>();
    if (workspace.rootPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a workspace folder first')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => const GitCommitDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final workspaceProvider = context.watch<WorkspaceProvider>();

    final session = chatProvider.activeSession;
    final messages = session?.messages ?? [];
    final isBusy = chatProvider.isAgentBusy;
    final isAutoDebugging = chatProvider.isAutoDebugging;

    return Container(
      color: AppTheme.darkBg,
      child: Column(
        children: [
          // Middle Top Bar: Chat Title & Superpowers Toolbar
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF131D30),
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_outlined, size: 16, color: AppTheme.primaryLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session?.title ?? 'Agent & Terminal Hub',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 🛡️ Auto-Debug Action Button
                Tooltip(
                  message: 'Self-Healing Auto-Debug Loop (Run tests -> AI analyzes errors -> patches code)',
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAutoDebugging ? AppTheme.warning : const Color(0xFF182A45),
                      foregroundColor: isAutoDebugging ? Colors.black : AppTheme.accentCyan,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 26),
                      side: const BorderSide(color: AppTheme.accentCyan, width: 0.8),
                    ),
                    icon: isAutoDebugging
                        ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black))
                        : const Icon(Icons.healing, size: 13),
                    label: Text(
                      isAutoDebugging ? 'Healing...' : 'Auto-Debug',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: isBusy ? null : _triggerAutoDebug,
                  ),
                ),
                const SizedBox(width: 6),

                // 🔀 AI Git Commit & Push Button
                Tooltip(
                  message: 'Inspect Git Diff, generate AI commit message, and push to origin',
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryLight,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 26),
                      side: const BorderSide(color: AppTheme.primary, width: 0.8),
                    ),
                    icon: const Icon(Icons.commit, size: 13),
                    label: const Text('Git Push', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                    onPressed: isBusy ? null : _openGitCommitDialog,
                  ),
                ),
                const SizedBox(width: 6),

                // Terminal Drawer Toggle
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: _showLiveTerminalDrawer ? AppTheme.accentCyan : Colors.white60,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    minimumSize: const Size(0, 26),
                  ),
                  icon: Icon(
                    _showLiveTerminalDrawer ? Icons.terminal : Icons.terminal_outlined,
                    size: 13,
                    color: _showLiveTerminalDrawer ? AppTheme.accentCyan : Colors.white60,
                  ),
                  label: Text(
                    _showLiveTerminalDrawer ? 'Hide Term' : 'Terminal',
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  onPressed: () => setState(() => _showLiveTerminalDrawer = !_showLiveTerminalDrawer),
                ),
                const SizedBox(width: 4),

                // New Chat Button
                IconButton(
                  icon: const Icon(Icons.add_comment_outlined, size: 15, color: Colors.white70),
                  splashRadius: 12,
                  tooltip: 'New Chat Session',
                  onPressed: () => chatProvider.createNewSession(),
                ),
                // Clear Chat Button
                if (messages.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, size: 15, color: Colors.white54),
                    splashRadius: 12,
                    tooltip: 'Clear Messages',
                    onPressed: () => chatProvider.clearActiveSessionMessages(),
                  ),
              ],
            ),
          ),

          // Provider & Key Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF0C1322),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    LlmProviderUtils.getProviderName(settingsProvider.activeProvider),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  settingsProvider.model,
                  style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Colors.white70),
                ),
                const Spacer(),
                if (!settingsProvider.hasValidApiKey && settingsProvider.activeProvider != LlmProviderType.ollama) ...[
                  InkWell(
                    onTap: () => showDialog(context: context, builder: (_) => const SettingsDialog()),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 12, color: AppTheme.warning),
                        const SizedBox(width: 4),
                        const Text('API Key Needed', style: TextStyle(fontSize: 10, color: AppTheme.warning, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Missing Workspace Warning
          if (workspaceProvider.rootPath == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: AppTheme.primary.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 13, color: AppTheme.primaryLight),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Select a workspace folder on the left panel to allow tool calling and terminal operations.',
                      style: TextStyle(fontSize: 10.5, color: AppTheme.primaryLight),
                    ),
                  ),
                  InkWell(
                    onTap: () => workspaceProvider.pickWorkspaceFolder(),
                    child: const Text(
                      'Open Folder',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),

          // Message Stream / Welcome Screen
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bolt, size: 40, color: AppTheme.primaryLight),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Flutter-X-Agent Hub',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Autonomous coding agent with Self-Healing Auto-Debug, Visual Diffs, Git Automation, and xrun Terminal runner.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.45)),
                          ),
                          const SizedBox(height: 20),
                          // Quick Action Chips
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: _quickActionChips.map((chipText) {
                              final isCmd = chipText.startsWith('xrun');
                              final isAuto = chipText.startsWith('🛡️');
                              final isGit = chipText.startsWith('🔀');

                              return ActionChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isCmd) const Icon(Icons.terminal, size: 12, color: AppTheme.accentCyan),
                                    if (isAuto) const Icon(Icons.healing, size: 12, color: AppTheme.warning),
                                    if (isGit) const Icon(Icons.commit, size: 12, color: AppTheme.primaryLight),
                                    if (isCmd || isAuto || isGit) const SizedBox(width: 4),
                                    Text(
                                      chipText,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: isCmd ? 'monospace' : null,
                                        color: isCmd
                                            ? AppTheme.accentCyan
                                            : isAuto
                                                ? AppTheme.warning
                                                : isGit
                                                    ? AppTheme.primaryLight
                                                    : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: isCmd
                                    ? const Color(0xFF0F2338)
                                    : isAuto
                                        ? const Color(0xFF2E2012)
                                        : const Color(0xFF1E293B),
                                side: BorderSide(
                                  color: isCmd
                                      ? AppTheme.accentCyan.withValues(alpha: 0.4)
                                      : isAuto
                                          ? AppTheme.warning.withValues(alpha: 0.4)
                                          : AppTheme.darkBorder,
                                ),
                                onPressed: () {
                                  if (isAuto) {
                                    _triggerAutoDebug();
                                  } else if (isGit) {
                                    _openGitCommitDialog();
                                  } else {
                                    _inputController.text = chipText;
                                    _sendMessage();
                                  }
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

          // Optional Live Terminal Console Drawer at Bottom
          if (_showLiveTerminalDrawer)
            Container(
              height: 220,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.darkBorder, width: 2)),
              ),
              child: const TerminalConsoleView(),
            ),

          // Quick Action Shortcut Strip
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFF0F1726),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(right: 6),
                  child: const Text(
                    '⚡ SHORTCUTS:',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38),
                  ),
                ),
                for (final chip in _quickActionChips)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        if (chip.startsWith('🛡️')) {
                          _triggerAutoDebug();
                        } else if (chip.startsWith('🔀')) {
                          _openGitCommitDialog();
                        } else {
                          _inputController.text = chip;
                          _sendMessage();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: chip.startsWith('xrun')
                              ? const Color(0xFF14243B)
                              : chip.startsWith('🛡️')
                                  ? const Color(0xFF281C10)
                                  : const Color(0xFF182336),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: chip.startsWith('xrun')
                                ? AppTheme.accentCyan.withValues(alpha: 0.3)
                                : chip.startsWith('🛡️')
                                    ? AppTheme.warning.withValues(alpha: 0.3)
                                    : AppTheme.darkBorder,
                          ),
                        ),
                        child: Text(
                          chip,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: chip.startsWith('xrun') ? 'monospace' : null,
                            color: chip.startsWith('xrun')
                                ? AppTheme.accentCyan
                                : chip.startsWith('🛡️')
                                    ? AppTheme.warning
                                    : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Input Box with xrun indicator
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF131D30),
              border: Border(top: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: CallbackShortcuts(
                        bindings: {
                          const SingleActivator(LogicalKeyboardKey.enter, control: false, meta: false, shift: false): _sendMessage,
                        },
                        child: TextField(
                          controller: _inputController,
                          focusNode: _focusNode,
                          maxLines: 4,
                          minLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: _isXRunDetected ? 'monospace' : null,
                            color: _isXRunDetected ? AppTheme.accentCyan : Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: isBusy
                                ? 'Agent / Auto-Debug is working...'
                                : 'Prompt agent, or type "xrun <cmd>" to execute in terminal...',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.35)),
                            prefixIcon: _isXRunDetected
                                ? Container(
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(Icons.terminal, size: 18, color: AppTheme.accentCyan),
                                  )
                                : const Icon(Icons.auto_awesome, size: 18, color: AppTheme.primaryLight),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBusy
                            ? const Color(0xFF334155)
                            : (_isXRunDetected ? AppTheme.accentCyan : AppTheme.primary),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isBusy ? null : _sendMessage,
                      child: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              _isXRunDetected ? Icons.play_arrow_rounded : Icons.send_rounded,
                              size: 18,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isXRunDetected
                          ? '⚡ xrun terminal execution active'
                          : 'Press Enter to send (Shift+Enter for newline)',
                      style: TextStyle(
                        fontSize: 10,
                        color: _isXRunDetected ? AppTheme.accentCyan : Colors.white.withValues(alpha: 0.3),
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

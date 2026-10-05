import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/llm_provider.dart';
import '../../providers/adversarial_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';
import '../dialogs/adversarial_config_dialog.dart';
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
    '⚔️ Adversarial Duel (Blue vs Red)',
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
    final advProvider = context.watch<AdversarialProvider>();

    final session = chatProvider.activeSession;
    final messages = session?.messages ?? [];
    final isBusy = chatProvider.isAgentBusy;
    final isAutoDebugging = chatProvider.isAutoDebugging;
    final isAdvMode = chatProvider.isAdversarialMode;

    _checkAutoScroll(session?.id, messages.length, isBusy || isAutoDebugging);

    return Container(
      color: AppTheme.darkBg,
      child: Column(
        children: [
          // Middle Top Bar: Single Chat Header & Superpower Toggles
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF131D30),
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.smart_toy_outlined, size: 16, color: AppTheme.primaryLight),
                  const SizedBox(width: 8),
                  Text(
                    session?.title ?? 'Agent Chat & Terminal Hub',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: 14),

                  // ⚔️ ADVERSARIAL MODE SWITCH PILL
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: isAdvMode ? const Color(0xFF1E1B4B) : const Color(0xFF0C1322),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isAdvMode ? const Color(0xFF6366F1) : AppTheme.darkBorder,
                        width: isAdvMode ? 1.2 : 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => chatProvider.toggleAdversarialMode(),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shield,
                                  size: 13,
                                  color: isAdvMode ? AppTheme.accentCyan : Colors.white38,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Adversarial Mode',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isAdvMode ? FontWeight.bold : FontWeight.normal,
                                    color: isAdvMode ? Colors.white : Colors.white60,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Transform.scale(
                                  scale: 0.65,
                                  child: Switch(
                                    value: isAdvMode,
                                    activeColor: AppTheme.accentCyan,
                                    activeTrackColor: const Color(0xFF4338CA),
                                    onChanged: (val) => chatProvider.setAdversarialMode(val),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isAdvMode) ...[
                          Container(width: 1, height: 16, color: const Color(0xFF4338CA)),
                          IconButton(
                            icon: const Icon(Icons.tune, size: 13, color: AppTheme.accentCyan),
                            tooltip: 'Configure Duel Models (Blue Builder vs Red Hacker)',
                            splashRadius: 12,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => const AdversarialConfigDialog(),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

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
          ),

          // Provider & Key Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            color: const Color(0xFF0C1322),
            child: Row(
              children: [
                if (isAdvMode) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF6366F1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flash_on, size: 11, color: AppTheme.accentCyan),
                        const SizedBox(width: 4),
                        Text(
                          'DUEL ACTIVE: Blue (${advProvider.config.blueModel}) ⚔️ Red (${advProvider.config.redModel})',
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${settingsProvider.activeProvider.displayName} • ${settingsProvider.model}',
                      style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppTheme.primaryLight, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const Spacer(),
                if (!settingsProvider.hasValidApiKey && settingsProvider.activeProvider != LlmProviderType.ollama) ...[
                  InkWell(
                    onTap: () => showDialog(context: context, builder: (_) => const SettingsDialog()),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 12, color: AppTheme.warning),
                        SizedBox(width: 4),
                        Text('API Key Needed', style: TextStyle(fontSize: 10, color: AppTheme.warning, fontWeight: FontWeight.bold)),
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

          // Unified Chat Message Stream / Welcome Screen
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
                              color: isAdvMode ? const Color(0xFF312E81) : AppTheme.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(isAdvMode ? Icons.shield : Icons.bolt, size: 40, color: AppTheme.primaryLight),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            isAdvMode ? '⚔️ Adversarial Mode Ready' : 'Flutter-X-Agent Hub',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isAdvMode
                                ? 'Blue Team (${advProvider.config.blueModel}) and Red Team (${advProvider.config.redModel}) will duel in this chat to build, attack, and harden code.'
                                : 'Autonomous coding agent with Adversarial Duel Mode, Self-Healing Auto-Debug, Visual Diffs, and xrun Terminal runner.',
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
                              final isAdv = chipText.startsWith('⚔️');

                              return ActionChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isCmd) const Icon(Icons.terminal, size: 12, color: AppTheme.accentCyan),
                                    if (isAuto) const Icon(Icons.healing, size: 12, color: AppTheme.warning),
                                    if (isGit) const Icon(Icons.commit, size: 12, color: AppTheme.primaryLight),
                                    if (isAdv) const Icon(Icons.shield, size: 12, color: AppTheme.accentCyan),
                                    if (isCmd || isAuto || isGit || isAdv) const SizedBox(width: 4),
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
                                                    : isAdv
                                                        ? AppTheme.accentCyan
                                                        : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: isCmd
                                    ? const Color(0xFF0F2338)
                                    : isAuto
                                        ? const Color(0xFF2E2012)
                                        : isAdv
                                            ? const Color(0xFF1E1B4B)
                                            : const Color(0xFF1E293B),
                                side: BorderSide(
                                  color: isCmd
                                      ? AppTheme.accentCyan.withValues(alpha: 0.4)
                                      : isAuto
                                          ? AppTheme.warning.withValues(alpha: 0.4)
                                          : isAdv
                                              ? const Color(0xFF6366F1)
                                              : AppTheme.darkBorder,
                                ),
                                onPressed: () {
                                  if (isAdv) {
                                    chatProvider.setAdversarialMode(true);
                                    _focusNode.requestFocus();
                                  } else if (isAuto) {
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

          // Input & In-chat Terminal Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isAdvMode ? const Color(0xFF0F1528) : const Color(0xFF131D30),
              border: Border(top: BorderSide(color: isAdvMode ? const Color(0xFF6366F1).withValues(alpha: 0.5) : AppTheme.darkBorder)),
            ),
            child: Column(
              children: [
                // xrun Live Indicator Pill
                if (_isXRunDetected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.terminal, size: 12, color: AppTheme.accentCyan),
                              SizedBox(width: 4),
                              Text(
                                'Terminal Runner Active: Will execute shell command directly in workspace',
                                style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.accentCyan),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isXRunDetected
                              ? const Color(0xFF0D1C2E)
                              : isAdvMode
                                  ? const Color(0xFF131B36)
                                  : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isXRunDetected
                                ? AppTheme.accentCyan
                                : isAdvMode
                                    ? const Color(0xFF6366F1)
                                    : AppTheme.darkBorder,
                            width: (_isXRunDetected || isAdvMode) ? 1.2 : 1.0,
                          ),
                        ),
                        child: TextField(
                          controller: _inputController,
                          focusNode: _focusNode,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: _isXRunDetected ? 'monospace' : null,
                            color: _isXRunDetected ? AppTheme.accentCyan : Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: isAdvMode
                                ? '⚔️ Duel: Enter feature to build & stress-test (Blue vs Red)...'
                                : 'Ask Agent (e.g. create a counter widget) or type "xrun flutter test"...',
                            hintStyle: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.35)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            prefixIcon: Icon(
                              _isXRunDetected
                                  ? Icons.terminal
                                  : isAdvMode
                                      ? Icons.shield
                                      : Icons.chat_bubble_outline,
                              size: 18,
                              color: _isXRunDetected || isAdvMode ? AppTheme.accentCyan : Colors.white38,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Send or Stop Button (48px Height)
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBusy
                              ? const Color(0xFFDC2626)
                              : (_isXRunDetected
                                  ? AppTheme.accentCyan
                                  : isAdvMode
                                      ? const Color(0xFF4F46E5)
                                      : AppTheme.primary),
                          foregroundColor: isBusy
                              ? Colors.white
                              : (_isXRunDetected ? Colors.black : Colors.white),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: Icon(
                          isBusy
                              ? Icons.stop_rounded
                              : (_isXRunDetected ? Icons.play_arrow : (isAdvMode ? Icons.flash_on : Icons.send_rounded)),
                          size: 16,
                        ),
                        label: Text(
                          isBusy
                              ? 'Stop'
                              : (isAdvMode ? 'Duel ⚔️' : (_isXRunDetected ? 'Run' : 'Send')),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

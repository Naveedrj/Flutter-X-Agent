import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';

class TerminalConsoleView extends StatefulWidget {
  const TerminalConsoleView({super.key});

  @override
  State<TerminalConsoleView> createState() => _TerminalConsoleViewState();
}

class _TerminalConsoleViewState extends State<TerminalConsoleView> {
  final TextEditingController _cmdController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<String> _getQuickCommands(WorkspaceProvider workspace) {
    final testCmd = workspace.defaultTestCommand;
    final isFlutter = testCmd.contains('flutter');
    return [
      'ls -la',
      'pwd',
      'git status',
      testCmd,
      if (isFlutter) 'flutter pub get',
      if (!isFlutter && testCmd.contains('npm')) 'npm install',
    ];
  }

  @override
  void dispose() {
    _cmdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
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

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceProvider>();
    final logs = workspace.terminalLogs;

    return Container(
      color: const Color(0xFF090D16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terminal Toolbar
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF131D30),
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 16, color: AppTheme.accentCyan),
                const SizedBox(width: 8),
                const Text(
                  'TERMINAL & TOOL EXECUTION CONSOLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                // Quick chips
                for (final qc in _getQuickCommands(workspace))
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ActionChip(
                      label: Text(qc, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: AppTheme.darkBorder),
                      onPressed: workspace.isCommandRunning
                          ? null
                          : () {
                              _cmdController.text = qc;
                              workspace.runManualTerminalCommand(qc);
                              _scrollToBottom();
                            },
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear_all, size: 16, color: Colors.white60),
                  tooltip: 'Clear Terminal Logs',
                  onPressed: () => workspace.clearTerminalLogs(),
                ),
              ],
            ),
          ),

          // Logs Output Area
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.terminal, size: 40, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 8),
                        Text(
                          'Ready for commands and agent operations.\nWorkspace: ${workspace.rootPath ?? "No folder selected"}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final line = logs[index];
                      Color textColor = Colors.white70;

                      if (line.startsWith('\$')) {
                        textColor = AppTheme.accentCyan;
                      } else if (line.startsWith('[ERR]') || line.startsWith('[ERROR]')) {
                        textColor = AppTheme.danger;
                      } else if (line.startsWith('[Exit 0]')) {
                        textColor = AppTheme.success;
                      } else if (line.startsWith('[Exit') || line.startsWith('[TIMEOUT]')) {
                        textColor = AppTheme.warning;
                      }

                      return SelectableText(
                        line,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textColor,
                          height: 1.35,
                        ),
                      );
                    },
                  ),
          ),

          // Interactive Command Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF101725),
              border: Border(top: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                const Text(
                  '\$ ',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentCyan,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _cmdController,
                    enabled: !workspace.isCommandRunning,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: workspace.rootPath == null
                          ? 'Select a workspace folder to run commands'
                          : 'Run shell command in workspace (e.g. git status, flutter build)...',
                      hintStyle: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        workspace.runManualTerminalCommand(val.trim());
                        _cmdController.clear();
                        _scrollToBottom();
                      }
                    },
                  ),
                ),
                if (workspace.isCommandRunning)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.send_rounded, size: 16, color: AppTheme.accentCyan),
                    onPressed: () {
                      final text = _cmdController.text.trim();
                      if (text.isNotEmpty) {
                        workspace.runManualTerminalCommand(text);
                        _cmdController.clear();
                        _scrollToBottom();
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

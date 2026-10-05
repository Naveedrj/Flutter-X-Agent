import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/file_diff.dart';
import '../models/tool_call_log.dart';
import '../services/auto_debug_service.dart';
import '../services/git_service.dart';
import '../services/snapshot_service.dart';
import '../services/storage_service.dart';
import '../services/unified_agent_service.dart';
import 'settings_provider.dart';
import 'workspace_provider.dart';

class ChatProvider extends ChangeNotifier {
  final StorageService storageService;
  final UnifiedAgentService agentService;
  final AutoDebugService autoDebugService;
  final GitService gitService;
  final SnapshotService snapshotService;
  final SettingsProvider settingsProvider;
  final WorkspaceProvider workspaceProvider;

  List<ChatSession> _sessions = [];
  ChatSession? _activeSession;
  bool _isAgentBusy = false;
  bool _isAutoDebugging = false;
  String _autoDebugStatus = '';

  // Active right panel tab: 0=Editor, 1=Saved, 2=WebView, 3=RAG, 4=Diff
  int _activeRightPanelTab = 0;

  ChatProvider({
    required this.storageService,
    required this.agentService,
    required this.autoDebugService,
    required this.gitService,
    required this.snapshotService,
    required this.settingsProvider,
    required this.workspaceProvider,
  }) {
    _loadSavedSessions();
  }

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  ChatSession? get activeSession => _activeSession;
  bool get isAgentBusy => _isAgentBusy;
  bool get isAutoDebugging => _isAutoDebugging;
  String get autoDebugStatus => _autoDebugStatus;
  int get activeRightPanelTab => _activeRightPanelTab;
  List<FileDiff> get recentDiffs => snapshotService.recentDiffs;

  void setActiveRightPanelTab(int index) {
    _activeRightPanelTab = index;
    notifyListeners();
  }

  void _loadSavedSessions() {
    _sessions = storageService.loadSessions();
    final activeId = storageService.getActiveSessionId();
    if (activeId != null && _sessions.any((s) => s.id == activeId)) {
      _activeSession = _sessions.firstWhere((s) => s.id == activeId);
    } else if (_sessions.isNotEmpty) {
      _activeSession = _sessions.first;
    } else {
      createNewSession();
    }
    notifyListeners();
  }

  ChatSession createNewSession({String? title}) {
    final session = ChatSession(
      title: title ?? 'New Agent Chat',
      workspacePath: workspaceProvider.rootPath ?? '',
    );
    _sessions.insert(0, session);
    _activeSession = session;
    _saveState();
    notifyListeners();
    return session;
  }

  void selectSession(String sessionId) {
    final found = _sessions.where((s) => s.id == sessionId).firstOrNull;
    if (found != null) {
      _activeSession = found;
      storageService.setActiveSessionId(sessionId);
      notifyListeners();
    }
  }

  void deleteSession(String sessionId) {
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_activeSession?.id == sessionId) {
      _activeSession = _sessions.isNotEmpty ? _sessions.first : null;
      if (_activeSession == null) {
        createNewSession();
      }
    }
    _saveState();
    notifyListeners();
  }

  void clearActiveSessionMessages() {
    if (_activeSession == null) return;
    _activeSession!.messages.clear();
    _activeSession!.webPreviewHtml = null;
    _saveState();
    notifyListeners();
  }

  Future<void> sendMessage(String userText) async {
    final trimmed = userText.trim();
    if (trimmed.isEmpty || _isAgentBusy) return;

    if (_activeSession == null) {
      createNewSession();
    }

    final session = _activeSession!;

    // Check for xrun command (e.g. 'xrun flutter test' or 'xrun flutter pub get')
    if (trimmed.toLowerCase().startsWith('xrun ') || trimmed.toLowerCase().startsWith('!run ')) {
      final cmd = trimmed.substring(trimmed.indexOf(' ') + 1).trim();
      await executeXRunCommand(cmd);
      return;
    }

    // Check for auto-debug trigger (e.g. 'autofix', 'auto-debug', 'fix tests')
    if (trimmed.toLowerCase() == 'autofix' || trimmed.toLowerCase() == 'auto-debug') {
      await runAutoDebug('flutter test');
      return;
    }

    final userMsg = ChatMessage(
      role: MessageRole.user,
      content: trimmed,
    );
    session.messages.add(userMsg);
    session.updatedAt = DateTime.now();

    if (session.messages.length == 1 || session.title == 'New Agent Chat') {
      final cleanTitle = trimmed.split('\n').first;
      session.title = cleanTitle.length > 35 ? '${cleanTitle.substring(0, 35)}...' : cleanTitle;
    }

    final assistantMsg = ChatMessage(
      role: MessageRole.assistant,
      content: '',
      isProcessing: true,
    );
    session.messages.add(assistantMsg);

    _isAgentBusy = true;
    notifyListeners();

    try {
      await agentService.runAgentTurn(
        provider: settingsProvider.activeProvider,
        apiKey: settingsProvider.apiKey,
        modelName: settingsProvider.model,
        temperature: settingsProvider.temperature,
        conversationHistory: session.messages.sublist(0, session.messages.length - 1),
        userPrompt: trimmed,
        onToolStarted: (toolLog) {
          assistantMsg.toolCalls.add(toolLog);
          notifyListeners();
        },
        onToolCompleted: (toolLog) {
          final idx = assistantMsg.toolCalls.indexWhere((t) => t.id == toolLog.id);
          if (idx != -1) {
            assistantMsg.toolCalls[idx] = toolLog;
          }
          notifyListeners();
        },
        onContentUpdated: (chunk) {
          assistantMsg.content = chunk;
          _extractWebPreview(session, chunk);
          notifyListeners();
        },
        onRagSourcesFound: (sources) {
          assistantMsg.ragSources.addAll(sources);
          notifyListeners();
        },
      );
    } catch (e) {
      assistantMsg.content = '❌ **Error running Agent**: $e';
    } finally {
      assistantMsg.isProcessing = false;
      _isAgentBusy = false;
      await workspaceProvider.refreshFileTree();
      _saveState();
      notifyListeners();
    }
  }

  Future<void> executeXRunCommand(String command) async {
    if (command.trim().isEmpty || _isAgentBusy) return;

    if (_activeSession == null) {
      createNewSession();
    }

    final session = _activeSession!;
    final userMsg = ChatMessage(
      role: MessageRole.user,
      content: 'xrun $command',
    );
    session.messages.add(userMsg);
    session.updatedAt = DateTime.now();

    final toolLog = ToolCallLog(
      id: const Uuid().v4(),
      toolName: 'execute_terminal_command',
      arguments: {'command': command},
      status: ToolStatus.running,
    );

    final assistantMsg = ChatMessage(
      role: MessageRole.assistant,
      content: '',
      toolCalls: [toolLog],
      isProcessing: true,
    );
    session.messages.add(assistantMsg);

    _isAgentBusy = true;
    notifyListeners();

    try {
      final workDir = workspaceProvider.rootPath ?? '.';
      final res = await workspaceProvider.terminalService.execute(command, workingDirectory: workDir);

      toolLog.status = res.isSuccess ? ToolStatus.success : ToolStatus.failed;
      toolLog.output = res.outputCombined;

      if (res.isSuccess) {
        assistantMsg.content = '✅ **Command completed successfully** (exit 0 in ${res.duration.inMilliseconds}ms)\n\n```bash\n\$ $command\n${res.stdout.trim()}\n```';
      } else {
        assistantMsg.content = '❌ **Command failed** (exit code ${res.exitCode})\n\n```bash\n${res.outputCombined}\n```';
      }
    } catch (e) {
      toolLog.status = ToolStatus.failed;
      toolLog.output = 'Error executing terminal command: $e';
      assistantMsg.content = '❌ **Terminal Execution Error**: $e';
    } finally {
      assistantMsg.isProcessing = false;
      _isAgentBusy = false;
      await workspaceProvider.refreshFileTree();
      _saveState();
      notifyListeners();
    }
  }

  // --- 🛡️ 1. SELF-HEALING AUTO-DEBUG LOOP ---
  Future<void> runAutoDebug(String testCommand) async {
    if (_isAgentBusy || _isAutoDebugging) return;
    _isAutoDebugging = true;
    _isAgentBusy = true;

    if (_activeSession == null) createNewSession();
    final session = _activeSession!;

    final userMsg = ChatMessage(
      role: MessageRole.user,
      content: '🛡️ **Auto-Debug & Fix**: `$testCommand`',
    );
    session.messages.add(userMsg);

    final assistantMsg = ChatMessage(
      role: MessageRole.assistant,
      content: '🛡️ **Starting Self-Healing Loop** for `$testCommand`...\n',
      isProcessing: true,
    );
    session.messages.add(assistantMsg);
    notifyListeners();

    try {
      final success = await autoDebugService.runSelfHealingLoop(
        testCommand: testCommand,
        provider: settingsProvider.activeProvider,
        apiKey: settingsProvider.apiKey,
        modelName: settingsProvider.model,
        temperature: settingsProvider.temperature,
        onStepUpdate: (step) {
          _autoDebugStatus = '${step.stage}: ${step.details}';
          assistantMsg.content += '\n- **[Step ${step.iteration}]** ${step.stage}: ${step.details}';
          notifyListeners();
        },
        onAgentMessage: (msg) {
          assistantMsg.content += '\n$msg';
          notifyListeners();
        },
      );

      if (success) {
        assistantMsg.content += '\n\n🎉 **Self-Healing Complete!** All tests are now passing.';
      } else {
        assistantMsg.content += '\n\n⚠️ **Auto-Debug Stopped**: Maximum iterations reached. Review changes in Diff Viewer.';
      }
    } catch (e) {
      assistantMsg.content += '\n\n❌ **Auto-Debug Error**: $e';
    } finally {
      assistantMsg.isProcessing = false;
      _isAutoDebugging = false;
      _isAgentBusy = false;
      await workspaceProvider.refreshFileTree();
      _saveState();
      notifyListeners();
    }
  }

  // --- ⏪ 2. ONE-CLICK SNAPSHOT & ROLLBACK ---
  Future<bool> rollbackTurn(String turnId) async {
    final count = await snapshotService.rollbackTurn(turnId);
    if (count > 0) {
      await workspaceProvider.refreshFileTree();
      if (_activeSession != null) {
        _activeSession!.messages.add(ChatMessage(
          role: MessageRole.system,
          content: '⏪ **Rollback Executed**: Reverted $count modified file(s) to previous state.',
        ));
      }
      _saveState();
      notifyListeners();
      return true;
    }
    return false;
  }

  // --- 🔀 3. AI-POWERED GIT COMMIT & PUSH ---
  Future<String> generateAiCommitMessage() async {
    final workDir = workspaceProvider.rootPath;
    if (workDir == null) return 'chore: update files';

    final diff = await gitService.getFullDiff(workDir);
    if (diff.isEmpty) return 'chore: minor updates';

    final prompt = '''
Generate a concise, professional Conventional Commit message (e.g. "feat(core): ...", "fix(agent): ...") based on this git diff:
```
${diff.length > 3000 ? diff.substring(0, 3000) : diff}
```
Respond with ONLY the commit message string, nothing else.
''';

    final buffer = StringBuffer();
    try {
      await agentService.runAgentTurn(
        provider: settingsProvider.activeProvider,
        apiKey: settingsProvider.apiKey,
        modelName: settingsProvider.model,
        temperature: 0.2,
        conversationHistory: [],
        userPrompt: prompt,
        onToolStarted: (_) {},
        onToolCompleted: (_) {},
        onContentUpdated: (chunk) => buffer.write(chunk),
        onRagSourcesFound: (_) {},
      );
      final msg = buffer.toString().trim().replaceAll('`', '');
      return msg.isNotEmpty ? msg : 'feat: workspace changes';
    } catch (_) {
      return 'feat: autonomous agent updates';
    }
  }

  void _extractWebPreview(ChatSession session, String text) {
    final htmlRegExp = RegExp(r'```(?:html|HTML)\s*([\s\S]*?)```');
    final match = htmlRegExp.firstMatch(text);
    if (match != null) {
      final code = match.group(1);
      if (code != null && code.trim().isNotEmpty) {
        session.webPreviewHtml = code.trim();
      }
    }
  }

  void updateWebPreviewHtml(String html) {
    if (_activeSession != null) {
      _activeSession!.webPreviewHtml = html;
      _saveState();
      notifyListeners();
    }
  }

  void _saveState() {
    storageService.saveSessions(_sessions);
    if (_activeSession != null) {
      storageService.setActiveSessionId(_activeSession!.id);
    }
  }
}

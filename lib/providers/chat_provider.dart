import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/tool_call_log.dart';
import '../services/gemini_agent_service.dart';
import '../services/storage_service.dart';
import 'settings_provider.dart';
import 'workspace_provider.dart';

class ChatProvider extends ChangeNotifier {
  final StorageService storageService;
  final GeminiAgentService geminiAgentService;
  final SettingsProvider settingsProvider;
  final WorkspaceProvider workspaceProvider;

  List<ChatSession> _sessions = [];
  ChatSession? _activeSession;
  bool _isAgentBusy = false;

  // Active right panel tab: 'chat', 'sessions', 'webview'
  int _activeRightPanelTab = 0;

  ChatProvider({
    required this.storageService,
    required this.geminiAgentService,
    required this.settingsProvider,
    required this.workspaceProvider,
  }) {
    _loadSavedSessions();
  }

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  ChatSession? get activeSession => _activeSession;
  bool get isAgentBusy => _isAgentBusy;
  int get activeRightPanelTab => _activeRightPanelTab;

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
    _activeRightPanelTab = 0; // switch to chat tab
    _saveState();
    notifyListeners();
    return session;
  }

  void selectSession(String sessionId) {
    final found = _sessions.where((s) => s.id == sessionId).firstOrNull;
    if (found != null) {
      _activeSession = found;
      _activeRightPanelTab = 0;
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

    // Check if user entered an 'xrun' command (e.g. 'xrun flutter pub get' or 'xrun ls -la')
    if (trimmed.toLowerCase().startsWith('xrun ') || trimmed.toLowerCase().startsWith('!run ')) {
      final cmd = trimmed.substring(trimmed.indexOf(' ') + 1).trim();
      await executeXRunCommand(cmd);
      return;
    }

    final userMsg = ChatMessage(
      role: MessageRole.user,
      content: trimmed,
    );
    session.messages.add(userMsg);
    session.updatedAt = DateTime.now();

    // Auto-name session from first user message
    if (session.messages.length == 1 || session.title == 'New Agent Chat') {
      final cleanTitle = trimmed.split('\n').first;
      session.title = cleanTitle.length > 35 ? '${cleanTitle.substring(0, 35)}...' : cleanTitle;
    }

    // Create placeholder assistant message
    final assistantMsg = ChatMessage(
      role: MessageRole.assistant,
      content: '',
      isProcessing: true,
    );
    session.messages.add(assistantMsg);

    _isAgentBusy = true;
    notifyListeners();

    bool fileSystemMutated = false;

    try {
      await geminiAgentService.runAgentTurn(
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
          if (['write_file', 'edit_file', 'move_file', 'delete_file'].contains(toolLog.toolName)) {
            fileSystemMutated = true;
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
      _saveState();

      if (fileSystemMutated) {
        // Refresh file tree in workspace provider
        workspaceProvider.refreshFileTree();
      }

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

  void _extractWebPreview(ChatSession session, String text) {
    // Check if response contains HTML code block
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

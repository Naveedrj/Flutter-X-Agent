import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/file_diff.dart';
import '../models/llm_provider.dart';
import '../models/tool_call_log.dart';
import '../services/adversarial_service.dart';
import '../services/auto_debug_service.dart';
import '../services/git_service.dart';
import '../services/snapshot_service.dart';
import '../services/storage_service.dart';
import '../services/unified_agent_service.dart';
import 'adversarial_provider.dart';
import 'settings_provider.dart';
import 'workspace_provider.dart';

class ChatProvider extends ChangeNotifier {
  final StorageService storageService;
  final UnifiedAgentService agentService;
  final AutoDebugService autoDebugService;
  final GitService gitService;
  final SnapshotService snapshotService;
  final AdversarialService adversarialService;
  final SettingsProvider settingsProvider;
  final WorkspaceProvider workspaceProvider;
  final AdversarialProvider adversarialProvider;

  List<ChatSession> _sessions = [];
  ChatSession? _activeSession;
  bool _isAgentBusy = false;
  bool _isAutoDebugging = false;
  String _autoDebugStatus = '';
  bool _isAdversarialMode = false;

  // Active right panel tab: 0=Editor, 1=Saved, 2=WebView, 3=RAG, 4=Diff
  int _activeRightPanelTab = 0;

  ChatProvider({
    required this.storageService,
    required this.agentService,
    required this.autoDebugService,
    required this.gitService,
    required this.snapshotService,
    required this.adversarialService,
    required this.settingsProvider,
    required this.workspaceProvider,
    required this.adversarialProvider,
  }) {
    _loadSavedSessions();
  }

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  ChatSession? get activeSession => _activeSession;
  bool get isAgentBusy => _isAgentBusy;
  bool get isAutoDebugging => _isAutoDebugging;
  String get autoDebugStatus => _autoDebugStatus;
  bool get isAdversarialMode => _isAdversarialMode;
  int get activeRightPanelTab => _activeRightPanelTab;
  List<FileDiff> get recentDiffs => snapshotService.recentDiffs;

  void setAdversarialMode(bool enabled) {
    _isAdversarialMode = enabled;
    notifyListeners();
  }

  void toggleAdversarialMode() {
    _isAdversarialMode = !_isAdversarialMode;
    notifyListeners();
  }

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

  void stopAgentTask() {
    if (!_isAgentBusy) return;
    agentService.cancelActiveTurn();
    _isAgentBusy = false;
    _isAutoDebugging = false;

    if (_activeSession != null && _activeSession!.messages.isNotEmpty) {
      final lastMsg = _activeSession!.messages.last;
      if (lastMsg.isProcessing) {
        lastMsg.isProcessing = false;
        lastMsg.statusStep = null;
        if (lastMsg.content.isEmpty) {
          lastMsg.content = '🛑 **Task stopped by user.**';
        } else if (!lastMsg.content.contains('Task stopped by user')) {
          lastMsg.content += '\n\n🛑 *Task stopped by user.*';
        }
      }
    }
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

    // If Adversarial Mode is Active, run the dual-agent debate loop in this chat!
    if (_isAdversarialMode) {
      await _runAdversarialChat(trimmed, session);
      return;
    }

    // Standard Autonomous Agent Flow
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

    final activeModelDisplay = '${settingsProvider.activeProvider.displayName} (${settingsProvider.model})';
    final assistantMsg = ChatMessage(
      role: MessageRole.assistant,
      content: '',
      isProcessing: true,
      modelName: activeModelDisplay,
      statusStep: '🔍 Inspecting workspace & context...',
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
        onStatusStepUpdated: (step) {
          assistantMsg.statusStep = step;
          notifyListeners();
        },
        onToolStarted: (toolLog) {
          assistantMsg.toolCalls.add(toolLog);
          assistantMsg.statusStep = toolLog.stepDescription ?? 'Executing ${toolLog.toolName}...';
          notifyListeners();
        },
        onToolCompleted: (toolLog) {
          final idx = assistantMsg.toolCalls.indexWhere((t) => t.id == toolLog.id);
          if (idx != -1) {
            assistantMsg.toolCalls[idx] = toolLog;
          }
          if (toolLog.diffStats != null) {
            assistantMsg.statusStep = '✅ Applied ${toolLog.toolName} (${toolLog.diffStats})';
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
      assistantMsg.statusStep = null;
      _isAgentBusy = false;
      await workspaceProvider.refreshFileTree();

      // Auto-reindex RAG knowledge in background if files were created, edited, moved, or deleted
      if (assistantMsg.toolCalls.any((t) =>
          t.toolName == 'write_file' ||
          t.toolName == 'edit_file' ||
          t.toolName == 'delete_file' ||
          t.toolName == 'move_file')) {
        unawaited(agentService.ragService.indexWorkspace(geminiApiKey: settingsProvider.apiKey));
      }

      _saveState();
      notifyListeners();
    }
  }

  /// Runs the Dual-Model Adversarial Loop (Blue Builder vs Red Hacker) in the main chat!
  Future<void> _runAdversarialChat(String prompt, ChatSession session) async {
    final userMsg = ChatMessage(
      role: MessageRole.user,
      content: prompt,
    );
    session.messages.add(userMsg);
    session.updatedAt = DateTime.now();

    if (session.messages.length == 1 || session.title == 'New Agent Chat') {
      final cleanTitle = prompt.split('\n').first;
      session.title = cleanTitle.length > 30 ? '⚔️ ${cleanTitle.substring(0, 30)}...' : '⚔️ $cleanTitle';
    }

    _isAgentBusy = true;
    notifyListeners();

    final cfg = adversarialProvider.config;

    // Blue Team ALWAYS inherits global settings (active provider, model, and key)
    final blueProvider = settingsProvider.activeProvider;
    final blueModel = settingsProvider.model;
    final blueKey = settingsProvider.apiKey;

    // Resolve Red API Key & Model
    final redProvider = cfg.redProvider;
    final redModel = cfg.redModel.isNotEmpty ? cfg.redModel : blueModel;
    String redKey = cfg.redApiKey.trim();
    if (redKey.isEmpty || redKey.contains('YOUR_API_KEY')) {
      redKey = storageService.getApiKey(provider: redProvider);
    }
    if (redKey.isEmpty || redKey.contains('YOUR_API_KEY')) {
      redKey = settingsProvider.apiKey;
    }

    String currentCode = workspaceProvider.currentFileContent;
    String lastBlueResponse = '';
    String lastRedCritique = '';
    int totalVulns = 0;
    int totalOpts = 0;

    try {
      for (int round = 1; round <= cfg.maxRounds; round++) {
        // -------------------------------------------------------------
        // 1. BLUE TEAM MESSAGE (BUILDER / ARCHITECT)
        // -------------------------------------------------------------
        final blueMsg = ChatMessage(
          role: MessageRole.assistant,
          speakerTag: 'blue',
          modelName: '${blueProvider.displayName} ($blueModel)',
          roundNumber: round,
          content: '🔵 **Blue Team (Builder)** is constructing implementation & architecture (Round $round)...',
          isProcessing: true,
        );
        session.messages.add(blueMsg);
        notifyListeners();

        final blueSystemPrompt = adversarialService.buildBlueSystemPrompt(round: round, focus: cfg.focus);
        final blueUserPrompt = round == 1
            ? adversarialService.buildBlueInitialPrompt(taskPrompt: prompt, existingCode: currentCode.isNotEmpty ? currentCode : null)
            : adversarialService.buildBlueRefactorPrompt(taskPrompt: prompt, previousCode: currentCode, redCritique: lastRedCritique);

        final blueResponse = await adversarialService.generateText(
          provider: blueProvider,
          model: blueModel,
          apiKey: blueKey,
          systemPrompt: blueSystemPrompt,
          userPrompt: blueUserPrompt,
          temperature: cfg.temperature,
        );

        lastBlueResponse = blueResponse;
        final extractedCode = adversarialService.extractCodeBlock(blueResponse);
        if (extractedCode != null && extractedCode.isNotEmpty) {
          currentCode = extractedCode;
        }

        blueMsg.content = blueResponse;
        blueMsg.hardenedCode = currentCode.isNotEmpty ? currentCode : null;
        blueMsg.isProcessing = false;
        _saveState();
        notifyListeners();

        // -------------------------------------------------------------
        // 2. RED TEAM MESSAGE (HACKER / SECURITY CRITIC)
        // -------------------------------------------------------------
        final redMsg = ChatMessage(
          role: MessageRole.assistant,
          speakerTag: 'red',
          modelName: '${redProvider.displayName} ($redModel)',
          roundNumber: round,
          content: '🔴 **Red Team (Hacker)** is penetrating code for exploits, race conditions, & bottlenecks (Round $round)...',
          isProcessing: true,
        );
        session.messages.add(redMsg);
        notifyListeners();

        final redSystemPrompt = adversarialService.buildRedSystemPrompt(focus: cfg.focus);
        final redUserPrompt = adversarialService.buildRedAttackPrompt(
          taskPrompt: prompt,
          codeToAttack: currentCode.isNotEmpty ? currentCode : blueResponse,
          round: round,
          maxRounds: cfg.maxRounds,
        );

        final redResponse = await adversarialService.generateText(
          provider: redProvider,
          model: redModel,
          apiKey: redKey,
          systemPrompt: redSystemPrompt,
          userPrompt: redUserPrompt,
          temperature: cfg.temperature,
        );

        lastRedCritique = redResponse;
        final vulns = adversarialService.parseVulnerabilities(redResponse);
        final opts = adversarialService.parseOptimizations(redResponse);
        totalVulns += vulns.length;
        totalOpts += opts.length;

        final isConsensus = redResponse.toUpperCase().contains('CONSENSUS_REACHED') ||
            redResponse.toUpperCase().contains('NO VULNERABILITIES FOUND') ||
            (vulns.isEmpty && opts.isEmpty && round > 1);

        redMsg.content = redResponse;
        redMsg.vulnerabilities = vulns;
        redMsg.optimizations = opts;
        redMsg.isProcessing = false;
        _saveState();
        notifyListeners();

        if (isConsensus || round == cfg.maxRounds) {
          final consensusMsg = ChatMessage(
            role: MessageRole.assistant,
            speakerTag: 'consensus',
            content: '### 🛡️ Adversarial Hardening Complete!\n\n'
                '• **Neutralized Vulnerabilities**: $totalVulns\n'
                '• **Performance Optimizations**: $totalOpts\n'
                '• **Debate Rounds**: $round of ${cfg.maxRounds}\n'
                '• **Status**: Verified 100/100 Hardened Consensus.',
            hardenedCode: currentCode.isNotEmpty ? currentCode : lastBlueResponse,
          );
          session.messages.add(consensusMsg);
          _saveState();
          notifyListeners();
          break;
        }
      }
    } catch (e) {
      // Remove any unfinished pending processing messages from session so no spinner is left behind
      session.messages.removeWhere((m) => m.isProcessing);

      session.messages.add(
        ChatMessage(
          role: MessageRole.assistant,
          content: '❌ **Adversarial Duel Error**: $e\n\n💡 *Tip: Check your API key in Settings (⚙️) or select a free hosted model like Groq / Gemini.*',
        ),
      );
    } finally {
      for (final msg in session.messages) {
        msg.isProcessing = false;
      }
      _isAgentBusy = false;
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

    final assistantMsg = ChatMessage(
      role: MessageRole.assistant,
      content: '',
      isProcessing: true,
    );
    session.messages.add(assistantMsg);

    _isAgentBusy = true;
    notifyListeners();

    final toolLog = ToolCallLog(
      id: const Uuid().v4(),
      toolName: 'execute_command',
      arguments: {'command': command},
      status: ToolStatus.running,
    );
    assistantMsg.toolCalls.add(toolLog);
    notifyListeners();

    final root = workspaceProvider.rootPath ?? '.';
    final result = await agentService.terminalService.execute(command, workingDirectory: root);

    toolLog.output = result.outputCombined;
    toolLog.status = result.isSuccess ? ToolStatus.success : ToolStatus.failed;

    assistantMsg.content = result.isSuccess
        ? '✅ Command completed with exit code 0.'
        : '⚠️ Command failed with exit code ${result.exitCode}.';
    assistantMsg.isProcessing = false;
    _isAgentBusy = false;

    await workspaceProvider.refreshFileTree();
    _saveState();
    notifyListeners();
  }

  Future<void> runAutoDebug(String testCommand) async {
    if (_isAgentBusy || workspaceProvider.rootPath == null) return;

    if (_activeSession == null) {
      createNewSession(title: '🛡️ Auto-Debug: $testCommand');
    }

    final session = _activeSession!;
    final userMsg = ChatMessage(
      role: MessageRole.user,
      content: '🛡️ **Run Self-Healing Auto-Debug Loop**: `$testCommand`',
    );
    session.messages.add(userMsg);

    final assistantMsg = ChatMessage(
      role: MessageRole.assistant,
      content: '🚀 Starting Self-Healing Auto-Debug Loop on workspace...',
      isProcessing: true,
    );
    session.messages.add(assistantMsg);

    _isAgentBusy = true;
    _isAutoDebugging = true;
    _autoDebugStatus = 'Running tests...';
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
          notifyListeners();
        },
        onAgentMessage: (chunk) {
          assistantMsg.content = chunk;
          notifyListeners();
        },
      );

      if (success) {
        _activeRightPanelTab = 4; // Switch to Diff tab
      }
    } catch (e) {
      assistantMsg.content = '❌ Auto-debug encountered an error: $e';
    } finally {
      assistantMsg.isProcessing = false;
      _isAgentBusy = false;
      _isAutoDebugging = false;
      _autoDebugStatus = '';
      await workspaceProvider.refreshFileTree();
      _saveState();
      notifyListeners();
    }
  }

  void updateWebPreviewHtml(String html) {
    if (activeSession != null) {
      activeSession!.webPreviewHtml = html;
      _saveState();
      notifyListeners();
    }
  }

  Future<String> generateAiCommitMessage() async {
    final root = workspaceProvider.rootPath ?? '.';
    return await gitService.generateCommitMessage(
      workingDirectory: root,
      agentService: agentService,
      provider: settingsProvider.activeProvider,
      apiKey: settingsProvider.apiKey,
      modelName: settingsProvider.model,
    );
  }

  void _extractWebPreview(ChatSession session, String text) {
    final htmlRegex = RegExp(r'```html\n([\s\S]*?)```');
    final match = htmlRegex.firstMatch(text);
    if (match != null) {
      session.webPreviewHtml = match.group(1);
    }
  }

  void _saveState() {
    storageService.saveSessions(_sessions);
    if (_activeSession != null) {
      storageService.setActiveSessionId(_activeSession!.id);
    }
  }
}

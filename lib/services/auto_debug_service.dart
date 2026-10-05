import 'dart:async';
import '../models/chat_message.dart';
import '../models/llm_provider.dart';
import 'terminal_service.dart';
import 'unified_agent_service.dart';
import 'workspace_service.dart';

class AutoDebugStep {
  final int iteration;
  final String stage;
  final String details;
  final bool isSuccess;
  final DateTime timestamp;

  AutoDebugStep({
    required this.iteration,
    required this.stage,
    required this.details,
    this.isSuccess = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AutoDebugService {
  final WorkspaceService workspaceService;
  final TerminalService terminalService;
  final UnifiedAgentService agentService;

  AutoDebugService({
    required this.workspaceService,
    required this.terminalService,
    required this.agentService,
  });

  Future<bool> runSelfHealingLoop({
    required String testCommand,
    required LlmProviderType provider,
    required String apiKey,
    required String modelName,
    required double temperature,
    required Function(AutoDebugStep) onStepUpdate,
    required Function(String chunk) onAgentMessage,
    int maxIterations = 5,
  }) async {
    final workDir = workspaceService.rootPath;
    if (workDir == null) {
      onStepUpdate(AutoDebugStep(
        iteration: 0,
        stage: 'Error',
        details: 'No workspace folder opened.',
        isSuccess: false,
      ));
      return false;
    }

    final history = <ChatMessage>[];

    for (int iter = 1; iter <= maxIterations; iter++) {
      onStepUpdate(AutoDebugStep(
        iteration: iter,
        stage: 'Running Tests ($iter/$maxIterations)',
        details: '\$ $testCommand',
        isSuccess: false,
      ));

      // 1. Run the test command
      final res = await terminalService.execute(testCommand, workingDirectory: workDir);

      if (res.isSuccess) {
        onStepUpdate(AutoDebugStep(
          iteration: iter,
          stage: 'Tests Passed 🎉',
          details: 'All tests passed with 0 errors in ${res.duration.inMilliseconds}ms!\n${res.stdout.trim()}',
          isSuccess: true,
        ));
        onAgentMessage('🎉 **Self-Healing Success**: All tests in `$testCommand` passed with 0 errors on iteration $iter!');
        return true;
      }

      // 2. Tests failed, feed stack trace to Agent
      onStepUpdate(AutoDebugStep(
        iteration: iter,
        stage: 'Analyzing & Patching Bugs',
        details: 'Exit code ${res.exitCode}. Instructing AI agent to read error stack trace and apply fixes...',
        isSuccess: false,
      ));

      final fixPrompt = '''
The test/build command `$testCommand` failed with exit code ${res.exitCode}.
Here is the error output and stack trace:
```
${res.outputCombined}
```
TASK:
1. Identify which file and lines caused this error.
2. Use `read_file` to inspect the code.
3. Use `edit_file` or `write_file` to fix the bugs and ensure all tests pass.
4. Report exactly what you changed.
''';

      await agentService.runAgentTurn(
        provider: provider,
        apiKey: apiKey,
        modelName: modelName,
        temperature: temperature,
        conversationHistory: history,
        userPrompt: fixPrompt,
        onToolStarted: (_) {},
        onToolCompleted: (_) {},
        onContentUpdated: onAgentMessage,
        onRagSourcesFound: (_) {},
      );

      // Add to debug history for context in next turn
      history.add(ChatMessage(role: MessageRole.user, content: fixPrompt));
      history.add(ChatMessage(role: MessageRole.assistant, content: 'Applied fix for iteration $iter.'));

      await Future.delayed(const Duration(milliseconds: 500));
    }

    onStepUpdate(AutoDebugStep(
      iteration: maxIterations,
      stage: 'Auto-Debug Limit Reached',
      details: 'Reached max iterations ($maxIterations). Please review recent agent edits in the Diff Viewer.',
      isSuccess: false,
    ));
    return false;
  }
}

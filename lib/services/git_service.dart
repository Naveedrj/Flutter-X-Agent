import '../models/llm_provider.dart';
import 'terminal_service.dart';
import 'unified_agent_service.dart';

class GitStatusResult {
  final bool isGitRepo;
  final List<String> changedFiles;
  final String statusSummary;
  final String diffPreview;

  GitStatusResult({
    required this.isGitRepo,
    required this.changedFiles,
    required this.statusSummary,
    required this.diffPreview,
  });

  bool get hasChanges => changedFiles.isNotEmpty;
}

class GitService {
  final TerminalService terminalService;

  GitService({required this.terminalService});

  Future<GitStatusResult> getStatus(String workingDirectory) async {
    final statusRes = await terminalService.execute(
      'git status --porcelain',
      workingDirectory: workingDirectory,
    );

    if (statusRes.exitCode != 0) {
      return GitStatusResult(
        isGitRepo: false,
        changedFiles: [],
        statusSummary: 'Not a git repository or git not found',
        diffPreview: '',
      );
    }

    final lines = statusRes.stdout.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
    final files = lines.map((l) => l.substring(l.length > 3 ? 3 : 0).trim()).toList();

    final diffRes = await terminalService.execute(
      'git diff --stat',
      workingDirectory: workingDirectory,
    );

    return GitStatusResult(
      isGitRepo: true,
      changedFiles: files,
      statusSummary: '${files.length} changed files',
      diffPreview: diffRes.stdout.trim(),
    );
  }

  Future<String> getFullDiff(String workingDirectory) async {
    final diffRes = await terminalService.execute(
      'git diff',
      workingDirectory: workingDirectory,
    );
    return diffRes.stdout.trim();
  }

  Future<TerminalCommandResult> commitAndPush({
    required String workingDirectory,
    required String commitMessage,
    String remote = 'origin',
    String branch = 'main',
  }) async {
    // Sanitize commit message for shell
    final escapedMessage = commitMessage.replaceAll('"', '\\"');
    final command = 'git add . && git commit -m "$escapedMessage" && git push $remote $branch';
    return await terminalService.execute(command, workingDirectory: workingDirectory);
  }

  Future<String> generateCommitMessage({
    required String workingDirectory,
    required UnifiedAgentService agentService,
    required LlmProviderType provider,
    required String apiKey,
    required String modelName,
  }) async {
    final diffStat = await terminalService.execute(
      'git status --short',
      workingDirectory: workingDirectory,
    );
    final files = diffStat.stdout.trim();
    if (files.isEmpty) {
      return 'chore: minor updates and optimizations';
    }
    final firstLines = files.split('\n').take(3).join(', ');
    return 'feat: updates across $firstLines';
  }
}

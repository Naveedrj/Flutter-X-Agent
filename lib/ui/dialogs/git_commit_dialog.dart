import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';

class GitCommitDialog extends StatefulWidget {
  const GitCommitDialog({super.key});

  @override
  State<GitCommitDialog> createState() => _GitCommitDialogState();
}

class _GitCommitDialogState extends State<GitCommitDialog> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _branchController = TextEditingController(text: 'main');
  final TextEditingController _remoteController = TextEditingController(text: 'origin');

  bool _isGeneratingMessage = true;
  bool _isPushing = false;
  List<String> _changedFiles = [];
  String? _executionResult;

  @override
  void initState() {
    super.initState();
    _loadGitInfo();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _branchController.dispose();
    _remoteController.dispose();
    super.dispose();
  }

  Future<void> _loadGitInfo() async {
    final chat = context.read<ChatProvider>();
    final workspace = context.read<WorkspaceProvider>();

    if (workspace.rootPath == null) return;

    final status = await chat.gitService.getStatus(workspace.rootPath!);
    setState(() {
      _changedFiles = status.changedFiles;
    });

    // Generate AI Commit Message
    final msg = await chat.generateAiCommitMessage();
    if (mounted) {
      setState(() {
        _messageController.text = msg;
        _isGeneratingMessage = false;
      });
    }
  }

  Future<void> _executeCommitAndPush() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;

    setState(() => _isPushing = true);
    final chat = context.read<ChatProvider>();
    final workspace = context.read<WorkspaceProvider>();

    final res = await chat.gitService.commitAndPush(
      workingDirectory: workspace.rootPath ?? '.',
      commitMessage: msg,
      remote: _remoteController.text.trim(),
      branch: _branchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isPushing = false;
        _executionResult = res.outputCombined;
      });
      if (res.isSuccess) {
        await workspace.refreshFileTree();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.commit, color: AppTheme.accentCyan, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'AI-Powered Git Commit & Push',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // Changed Files Header
            Row(
              children: [
                Text(
                  'CHANGED FILES (${_changedFiles.length})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 90),
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF131D30),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: _changedFiles.isEmpty
                  ? const Text('No changed files detected by git status', style: TextStyle(fontSize: 11.5, color: Colors.white38))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _changedFiles.map((f) {
                          return Text(
                            '• $f',
                            style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: AppTheme.primaryLight),
                          );
                        }).toList(),
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // AI Commit Message Field
            Row(
              children: [
                const Text(
                  'COMMIT MESSAGE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54),
                ),
                const SizedBox(width: 8),
                if (_isGeneratingMessage)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentCyan)),
                      SizedBox(width: 4),
                      Text('AI is analyzing diff...', style: TextStyle(fontSize: 10, color: AppTheme.accentCyan)),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('AI-Generated', style: TextStyle(fontSize: 9.5, color: AppTheme.primaryLight, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _messageController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. feat(agent): support multi-provider LLMs and auto-debug',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),

            const SizedBox(height: 12),

            // Remote and Branch
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REMOTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _remoteController,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BRANCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _branchController,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (_executionResult != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1322),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _executionResult!,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white70),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: _isPushing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload, size: 16),
                  label: Text(_isPushing ? 'Pushing...' : 'Commit & Push'),
                  onPressed: _isPushing ? null : _executeCommitAndPush,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

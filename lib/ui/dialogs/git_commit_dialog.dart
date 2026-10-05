import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _filesScrollController = ScrollController();
  final ScrollController _outputScrollController = ScrollController();

  bool _isGeneratingMessage = true;
  bool _isPushing = false;
  List<String> _changedFiles = [];
  String? _executionResult;
  bool _isSuccess = false;

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
    _mainScrollController.dispose();
    _filesScrollController.dispose();
    _outputScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGitInfo() async {
    final chat = context.read<ChatProvider>();
    final workspace = context.read<WorkspaceProvider>();

    if (workspace.rootPath == null) return;

    final status = await chat.gitService.getStatus(workspace.rootPath!);
    if (mounted) {
      setState(() {
        _changedFiles = status.changedFiles;
      });
    }

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
        _isSuccess = res.isSuccess;
        _executionResult = res.outputCombined;
      });
      if (res.isSuccess) {
        await workspace.refreshFileTree();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: screenHeight * 0.88,
        ),
        child: Container(
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
                  const Expanded(
                    child: Text(
                      'AI-Powered Git Commit & Push',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Scrollable Body
              Flexible(
                child: Scrollbar(
                  controller: _mainScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _mainScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Changed Files Header
                        Row(
                          children: [
                            Text(
                              'CHANGED FILES (${_changedFiles.length})',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54),
                            ),
                            const Spacer(),
                            if (_changedFiles.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${_changedFiles.length} modified / untracked',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.primaryLight),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Scrollable Changed Files List
                        Container(
                          constraints: const BoxConstraints(minHeight: 45, maxHeight: 125),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF131D30),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.darkBorder),
                          ),
                          child: _changedFiles.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'No changed files detected by git status',
                                    style: TextStyle(fontSize: 11.5, color: Colors.white38),
                                  ),
                                )
                              : Scrollbar(
                                  controller: _filesScrollController,
                                  thumbVisibility: true,
                                  child: ListView.builder(
                                    controller: _filesScrollController,
                                    shrinkWrap: true,
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(8),
                                    itemCount: _changedFiles.length,
                                    itemBuilder: (context, index) {
                                      final file = _changedFiles[index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.description_outlined, size: 13, color: AppTheme.primaryLight),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: SelectableText(
                                                file,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontFamily: 'monospace',
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),

                        const SizedBox(height: 14),

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
                                  SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentCyan),
                                  ),
                                  SizedBox(width: 6),
                                  Text('AI analyzing diff...', style: TextStyle(fontSize: 10, color: AppTheme.accentCyan)),
                                ],
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'AI-Generated',
                                  style: TextStyle(fontSize: 9.5, color: AppTheme.primaryLight, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _messageController,
                          minLines: 2,
                          maxLines: 4,
                          style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace', color: Colors.white),
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

                        // Execution Terminal Output Section
                        if (_executionResult != null) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(
                                _isSuccess ? Icons.check_circle_outline : Icons.info_outline,
                                size: 14,
                                color: _isSuccess ? AppTheme.success : AppTheme.warning,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isSuccess ? 'EXECUTION OUTPUT (SUCCESS)' : 'EXECUTION OUTPUT',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: _isSuccess ? AppTheme.success : Colors.white54,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 13, color: Colors.white54),
                                tooltip: 'Copy Output',
                                splashRadius: 12,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _executionResult!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Output copied to clipboard'), duration: Duration(seconds: 1)),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close, size: 13, color: Colors.white54),
                                tooltip: 'Dismiss Output',
                                splashRadius: 12,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() => _executionResult = null);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            constraints: const BoxConstraints(minHeight: 40, maxHeight: 130),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C1322),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _isSuccess ? AppTheme.success.withValues(alpha: 0.4) : AppTheme.darkBorder,
                              ),
                            ),
                            child: Scrollbar(
                              controller: _outputScrollController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _outputScrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(8),
                                child: SelectableText(
                                  _executionResult!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: _isSuccess ? Colors.white70 : Colors.orangeAccent.shade100,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Action Buttons Footer
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
      ),
    );
  }
}

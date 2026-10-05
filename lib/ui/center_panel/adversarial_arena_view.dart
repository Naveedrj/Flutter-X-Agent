import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../models/adversarial_debate.dart';
import '../../providers/adversarial_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';
import '../dialogs/adversarial_config_dialog.dart';

class AdversarialArenaView extends StatefulWidget {
  const AdversarialArenaView({super.key});

  @override
  State<AdversarialArenaView> createState() => _AdversarialArenaViewState();
}

class _AdversarialArenaViewState extends State<AdversarialArenaView> {
  final TextEditingController _taskController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _useActiveFile = true;

  @override
  void dispose() {
    _taskController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startDuel() async {
    final prompt = _taskController.text.trim();
    if (prompt.isEmpty) return;

    final adv = context.read<AdversarialProvider>();
    final workspace = context.read<WorkspaceProvider>();

    String? targetPath;
    String? existingContent;

    if (_useActiveFile && workspace.currentOpenFilePath != null) {
      targetPath = workspace.currentOpenFilePath;
      existingContent = workspace.currentFileContent;
    }

    await adv.startDuel(
      taskPrompt: prompt,
      targetFilePath: targetPath,
      existingFileContent: existingContent,
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final adv = context.watch<AdversarialProvider>();
    final workspace = context.watch<WorkspaceProvider>();
    final chat = context.read<ChatProvider>();
    final session = adv.currentSession;
    final config = adv.config;

    return Container(
      color: AppTheme.darkBg,
      child: Column(
        children: [
          // Top Control Header
          _buildArenaHeader(adv, config),

          // Battlefield Feed / Empty State
          Expanded(
            child: session == null || session.turns.isEmpty
                ? _buildEmptyState(workspace)
                : _buildDebateFeed(session, adv, workspace, chat),
          ),

          // Bottom Prompt Input Bar
          _buildInputBar(adv, workspace),
        ],
      ),
    );
  }

  Widget _buildArenaHeader(AdversarialProvider adv, AdversarialConfig config) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.flash_on, color: AppTheme.accentCyan, size: 18),
            const SizedBox(width: 6),
            const Text(
              'ADVERSARIAL ARENA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),

            // Blue Model Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFF2563EB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield, size: 11, color: AppTheme.accentCyan),
                  const SizedBox(width: 4),
                  Text(
                    'Blue: ${config.blueModel}',
                    style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            const Text('⚔️', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 5),

            // Red Model Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF881337).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFFE11D48)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.coronavirus_outlined, size: 11, color: Color(0xFFF87171)),
                  const SizedBox(width: 4),
                  Text(
                    'Red: ${config.redModel}',
                    style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFFF87171), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Focus Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Text(
                config.focus.shortLabel,
                style: const TextStyle(fontSize: 10.5, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 8),

            // Config Dialog Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppTheme.darkBorder),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 28),
              ),
              icon: const Icon(Icons.tune, size: 13),
              label: const Text('Configure Duel', style: TextStyle(fontSize: 11)),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const AdversarialConfigDialog(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(WorkspaceProvider workspace) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Icon(Icons.military_tech_outlined, size: 34, color: AppTheme.primaryLight),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Dual-Model Adversarial Development',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pit two AI models against each other in real-time self-play. Blue Team builds the code, while Red Team aggressively hunts for vulnerabilities, race conditions, memory leaks, and O(N²) bottlenecks until bulletproof consensus is reached.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Feature cards
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.code,
                      title: '🔵 Blue Team (Builder)',
                      desc: 'Architects clean code, provides unit tests, and patches identified flaws.',
                      color: AppTheme.accentCyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.bug_report_outlined,
                      title: '🔴 Red Team (Hacker)',
                      desc: 'Attacks code, finding security flaws, concurrency bugs, and performance leaks.',
                      color: const Color(0xFFF87171),
                    ),
                  ),
                ],
              ),

              if (workspace.currentOpenFilePath != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attach_file, size: 14, color: AppTheme.accentCyan),
                      const SizedBox(width: 6),
                      Text(
                        'Ready to harden: ${workspace.currentOpenFilePath}',
                        style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(fontSize: 11, color: Colors.white60, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildDebateFeed(
    AdversarialSession session,
    AdversarialProvider adv,
    WorkspaceProvider workspace,
    ChatProvider chat,
  ) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: session.turns.length + (adv.isDuelRunning ? 1 : 0) + (session.status == AdversarialSessionStatus.completed ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < session.turns.length) {
            final turn = session.turns[index];
            return _buildTurnCard(turn);
          }

          if (adv.isDuelRunning && index == session.turns.length) {
            return _buildRunningIndicator(adv);
          }

          // Completed Footer Banner & Action Bar
          return _buildConsensusFooter(session, adv, workspace, chat);
        },
      ),
    );
  }

  Widget _buildTurnCard(DebateTurn turn) {
    final isBlue = turn.isBlue;
    final cardBorder = isBlue ? const Color(0xFF2563EB) : (turn.isConsensus ? AppTheme.success : const Color(0xFFE11D48));
    final cardBg = isBlue ? const Color(0xFF0C172E) : (turn.isConsensus ? const Color(0xFF0B2416) : const Color(0xFF1F1017));
    final speakerColor = isBlue ? AppTheme.accentCyan : (turn.isConsensus ? AppTheme.success : const Color(0xFFF87171));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: cardBorder.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Turn Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: cardBorder.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                Icon(
                  isBlue ? Icons.shield_outlined : (turn.isConsensus ? Icons.verified : Icons.bug_report_outlined),
                  size: 16,
                  color: speakerColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'ROUND ${turn.round}: ${turn.speaker.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: speakerColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    turn.modelName,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white60),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary headline
                Text(
                  turn.summary,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 8),

                // Tags for Red Team
                if (turn.vulnerabilitiesFound.isNotEmpty || turn.optimizationsProposed.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (turn.vulnerabilitiesFound.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '🚨 ${turn.vulnerabilitiesFound.length} Vulnerabilities',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (turn.optimizationsProposed.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '⚡ ${turn.optimizationsProposed.length} Optimizations',
                            style: const TextStyle(fontSize: 10.5, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Full critique or proposal in Markdown
                MarkdownBody(
                  data: turn.fullContent,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
                    code: const TextStyle(
                      backgroundColor: Color(0xFF0F172A),
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: AppTheme.primaryLight,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                  ),
                ),

                // If code is present, provide quick copy button
                if (turn.codeSnippet != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentCyan,
                          side: const BorderSide(color: AppTheme.accentCyan, width: 0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: const Size(0, 26),
                        ),
                        icon: const Icon(Icons.copy, size: 12),
                        label: const Text('Copy Hardened Code', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: turn.codeSnippet!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Hardened code copied to clipboard!'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningIndicator(AdversarialProvider adv) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131D30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              adv.statusMessage ?? 'Adversarial duel in progress...',
              style: const TextStyle(fontSize: 12.5, color: Colors.white, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsensusFooter(
    AdversarialSession session,
    AdversarialProvider adv,
    WorkspaceProvider workspace,
    ChatProvider chat,
  ) {
    final targetPath = session.targetFilePath ?? workspace.currentOpenFilePath ?? 'lib/main.dart';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: AppTheme.success, size: 22),
              const SizedBox(width: 8),
              const Text(
                'ADVERSARIAL DUEL COMPLETED',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('100/100 Hardened', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Neutralized ${session.totalVulnerabilitiesNeutralized} vulnerabilities & applied ${session.totalOptimizationsApplied} performance optimizations.',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 14),

          // Action buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.save_as_outlined, size: 16),
                label: Text('Apply to $targetPath'),
                onPressed: () async {
                  await adv.applyHardenedCode(targetPath);
                  await workspace.refreshFileTree();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hardened code safely applied to $targetPath! (Snapshot created)'), backgroundColor: AppTheme.success),
                    );
                  }
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.darkBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.play_arrow_outlined, size: 16, color: AppTheme.accentCyan),
                label: Text('Run xrun ${workspace.defaultTestCommand}'),
                onPressed: () {
                  chat.executeXRunCommand(workspace.defaultTestCommand);
                },
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white60),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('New Duel'),
                onPressed: () => adv.clearCurrentSession(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(AdversarialProvider adv, WorkspaceProvider workspace) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Column(
        children: [
          if (workspace.currentOpenFilePath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: _useActiveFile,
                    activeColor: AppTheme.primary,
                    onChanged: (val) => setState(() => _useActiveFile = val ?? true),
                  ),
                  Expanded(
                    child: Text(
                      'Include active workspace file: ${workspace.currentOpenFilePath}',
                      style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taskController,
                  enabled: !adv.isDuelRunning,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter feature to build or vulnerability/architecture to harden...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: const Icon(Icons.shield, color: AppTheme.accentCyan, size: 18),
                  ),
                  onSubmitted: (_) => _startDuel(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                icon: adv.isDuelRunning
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.flash_on, size: 18),
                label: Text(adv.isDuelRunning ? 'Dueling...' : 'Start Duel ⚔️'),
                onPressed: adv.isDuelRunning ? null : _startDuel,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

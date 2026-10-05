import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/file_diff.dart';
import '../../providers/chat_provider.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';

class VisualDiffView extends StatefulWidget {
  const VisualDiffView({super.key});

  @override
  State<VisualDiffView> createState() => _VisualDiffViewState();
}

class _VisualDiffViewState extends State<VisualDiffView> {
  int _selectedDiffIndex = 0;

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final workspaceProvider = context.watch<WorkspaceProvider>();
    final diffs = chatProvider.recentDiffs;

    if (diffs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.difference_outlined, size: 48, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(height: 12),
              const Text(
                'No Recent Agent Diffs',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'When the AI agent modifies files or when you run auto-debug,\nbefore/after diffs appear here with Accept/Revert controls.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedDiffIndex >= diffs.length) {
      _selectedDiffIndex = 0;
    }
    final activeDiff = diffs[_selectedDiffIndex];

    return Container(
      color: AppTheme.darkBg,
      child: Column(
        children: [
          // Header: File Selector & Stats
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF131D30),
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.difference, size: 16, color: AppTheme.accentCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedDiffIndex,
                      dropdownColor: AppTheme.darkSurface,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
                      items: List.generate(diffs.length, (idx) {
                        final d = diffs[idx];
                        return DropdownMenuItem<int>(
                          value: idx,
                          child: Text(
                            '${d.filePath} (+${d.additions} -${d.deletions})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDiffIndex = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Revert Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger, width: 0.8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 26),
                  ),
                  icon: const Icon(Icons.undo, size: 13),
                  label: const Text('Revert File', style: TextStyle(fontSize: 11)),
                  onPressed: () async {
                    await chatProvider.snapshotService.revertSingleFile(
                      activeDiff.filePath,
                      activeDiff.originalContent,
                    );
                    await workspaceProvider.refreshFileTree();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          // Diff Summary Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF0C1322),
            child: Row(
              children: [
                Text(
                  activeDiff.filePath,
                  style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+${activeDiff.additions}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.success, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-${activeDiff.deletions}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.danger, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Visual Diff Line-by-Line List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: activeDiff.lines.length,
              itemBuilder: (context, index) {
                final line = activeDiff.lines[index];
                Color bgColor = Colors.transparent;
                Color textColor = Colors.white70;
                String prefix = ' ';

                if (line.type == DiffLineType.added) {
                  bgColor = const Color(0xFF10281E);
                  textColor = const Color(0xFF4ADE80);
                  prefix = '+';
                } else if (line.type == DiffLineType.deleted) {
                  bgColor = const Color(0xFF2E1318);
                  textColor = const Color(0xFFF87171);
                  prefix = '-';
                }

                return Container(
                  color: bgColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Old line number
                      SizedBox(
                        width: 32,
                        child: Text(
                          line.oldLineNumber?.toString() ?? '',
                          style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white.withValues(alpha: 0.25)),
                          textAlign: TextAlign.end,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // New line number
                      SizedBox(
                        width: 32,
                        child: Text(
                          line.newLineNumber?.toString() ?? '',
                          style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white.withValues(alpha: 0.25)),
                          textAlign: TextAlign.end,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Prefix (+, -, space)
                      Text(
                        prefix,
                        style: TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: textColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      // Content
                      Expanded(
                        child: SelectableText(
                          line.text,
                          style: TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: textColor, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

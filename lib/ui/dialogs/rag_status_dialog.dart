import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';

class RagStatusDialog extends StatelessWidget {
  const RagStatusDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceProvider>();
    final stats = workspace.ragStats;
    final timeStr = DateFormat('MMM d, h:mm a').format(stats.lastIndexed);

    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_outlined, color: AppTheme.accentCyan, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'RAG Knowledge Base Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            _buildStatRow('Workspace Root', workspace.rootPath ?? 'No folder selected'),
            const SizedBox(height: 10),
            _buildStatRow('Indexed Files', '${stats.totalFiles} files'),
            const SizedBox(height: 10),
            _buildStatRow('Code Chunks in Index', '${stats.totalChunks} chunks'),
            const SizedBox(height: 10),
            _buildStatRow('Last Indexed', timeStr),
            const SizedBox(height: 10),
            _buildStatRow(
              'Indexing Status',
              stats.isIndexing ? 'Indexing in progress...' : 'Ready',
              statusColor: stats.isIndexing ? AppTheme.warning : AppTheme.success,
            ),

            if (stats.currentAction != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Text(
                  stats.currentAction!,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.primaryLight),
                ),
              ),
            ],

            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.darkBorder),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Re-index Workspace'),
                  onPressed: stats.isIndexing
                      ? null
                      : () async {
                          await workspace.triggerRagReindex();
                        },
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? statusColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: statusColor ?? Colors.white,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

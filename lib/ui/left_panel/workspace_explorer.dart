import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';
import '../dialogs/new_file_dialog.dart';
import '../dialogs/rag_status_dialog.dart';
import 'file_tree_view.dart';

class WorkspaceExplorer extends StatelessWidget {
  const WorkspaceExplorer({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceProvider>();
    final root = workspace.rootPath;
    final folderName = root != null ? p.basename(root) : 'No Workspace';

    return Container(
      color: AppTheme.darkSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Folder Picker Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_shared_outlined, size: 18, color: AppTheme.primaryLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folderName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (root != null)
                        Text(
                          root,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Colors.white.withOpacity(0.4),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 18, color: Colors.white70),
                  tooltip: 'Open Local Folder from Machine',
                  onPressed: () => workspace.pickWorkspaceFolder(),
                ),
              ],
            ),
          ),

          // Action Toolbar (New File, New Folder, Refresh, RAG info)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF131C2D),
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 4),
                const Text(
                  'EXPLORER',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.white54),
                ),
                const Spacer(),
                if (root != null) ...[
                  IconButton(
                    icon: const Icon(Icons.note_add_outlined, size: 16, color: Colors.white70),
                    splashRadius: 12,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'New File',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const NewFileDialog(isDirectory: false),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: Colors.white70),
                    splashRadius: 12,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'New Folder',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const NewFileDialog(isDirectory: true),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
                    splashRadius: 12,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'Refresh Files',
                    onPressed: () => workspace.refreshFileTree(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.hub_outlined, size: 16, color: AppTheme.accentCyan),
                    splashRadius: 12,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'RAG Knowledge Base Status',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const RagStatusDialog(),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          // File Tree or Empty Workspace Placeholder
          Expanded(
            child: root == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_outlined, size: 48, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 12),
                          const Text(
                            'No folder opened',
                            style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.folder_open, size: 16),
                            label: const Text('Select Folder', style: TextStyle(fontSize: 12)),
                            onPressed: () => workspace.pickWorkspaceFolder(),
                          ),
                        ],
                      ),
                    ),
                  )
                : workspace.isLoadingFiles
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                        ),
                      )
                    : SingleChildScrollView(
                        child: FileTreeView(items: workspace.fileTree),
                      ),
          ),

          // Bottom RAG status strip
          if (root != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF111927),
                border: Border(top: BorderSide(color: AppTheme.darkBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: workspace.ragStats.isIndexing ? AppTheme.warning : AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      workspace.ragStats.isIndexing
                          ? (workspace.ragStats.currentAction ?? 'RAG Indexing...')
                          : 'RAG: ${workspace.ragStats.totalChunks} chunks indexed',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.white.withOpacity(0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

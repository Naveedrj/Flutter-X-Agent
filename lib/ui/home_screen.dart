import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workspace_provider.dart';
import 'app_theme.dart';
import 'center_panel/agent_chat_terminal_view.dart';
import 'dialogs/rag_status_dialog.dart';
import 'dialogs/settings_dialog.dart';
import 'left_panel/workspace_explorer.dart';
import 'right_panel/right_panel_container.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLeftPanelVisible = true;
  bool _isRightPanelVisible = true;

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceProvider>();
    final settings = context.watch<SettingsProvider>();

    final root = workspace.rootPath;
    final folderName = root != null ? p.basename(root) : 'Select Folder';

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Column(
        children: [
          // Top Navigation Bar
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF131D30),
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                // Logo & Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.bolt, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'AGENTIC',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Gemini 1.5/2.0',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 24),

                // Workspace Folder Indicator / Selector Button
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => workspace.pickWorkspaceFolder(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.darkBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_open, size: 15, color: AppTheme.warning),
                        const SizedBox(width: 6),
                        Text(
                          folderName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white54),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // RAG status badge
                if (root != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const RagStatusDialog(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF162238),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.hub_outlined,
                            size: 14,
                            color: workspace.ragStats.isIndexing ? AppTheme.warning : AppTheme.accentCyan,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            workspace.ragStats.isIndexing ? 'RAG Indexing...' : 'RAG: ${workspace.ragStats.totalChunks}',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),

                const Spacer(),

                // Model Selector in Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: SettingsProvider.availableModels.contains(settings.model)
                          ? settings.model
                          : SettingsProvider.availableModels.first,
                      dropdownColor: AppTheme.darkSurface,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white),
                      items: SettingsProvider.availableModels.map((m) {
                        return DropdownMenuItem<String>(
                          value: m,
                          child: Text(m),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) settings.setModel(val);
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // API Key status pill
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const SettingsDialog(),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: settings.hasValidApiKey
                          ? AppTheme.success.withOpacity(0.15)
                          : AppTheme.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: settings.hasValidApiKey ? AppTheme.success : AppTheme.warning,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          settings.hasValidApiKey ? Icons.check_circle : Icons.warning_amber_rounded,
                          size: 13,
                          color: settings.hasValidApiKey ? AppTheme.success : AppTheme.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          settings.hasValidApiKey ? 'API Key Active' : 'API Key Placeholder',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: settings.hasValidApiKey ? AppTheme.success : AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Settings icon button
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 18, color: Colors.white70),
                  tooltip: 'Settings',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const SettingsDialog(),
                    );
                  },
                ),

                const SizedBox(width: 4),

                // Panel toggle buttons
                IconButton(
                  icon: Icon(
                    _isLeftPanelVisible ? Icons.dock : Icons.dock_outlined,
                    size: 18,
                    color: _isLeftPanelVisible ? AppTheme.primaryLight : Colors.white38,
                  ),
                  tooltip: 'Toggle Explorer Panel',
                  onPressed: () => setState(() => _isLeftPanelVisible = !_isLeftPanelVisible),
                ),
                IconButton(
                  icon: Icon(
                    _isRightPanelVisible ? Icons.vertical_split : Icons.vertical_split_outlined,
                    size: 18,
                    color: _isRightPanelVisible ? AppTheme.primaryLight : Colors.white38,
                  ),
                  tooltip: 'Toggle Agent & Saved Chats Panel',
                  onPressed: () => setState(() => _isRightPanelVisible = !_isRightPanelVisible),
                ),
              ],
            ),
          ),

          // Main 3-Panel Workspace
          Expanded(
            child: Row(
              children: [
                // 1. Left Panel (Workspace Explorer)
                if (_isLeftPanelVisible)
                  const SizedBox(
                    width: 260,
                    child: WorkspaceExplorer(),
                  ),

                if (_isLeftPanelVisible)
                  const VerticalDivider(width: 1, color: AppTheme.darkBorder),

                // 2. Center Panel (Agent Chat & Mixed Terminal Hub with xrun)
                const Expanded(
                  flex: 5,
                  child: AgentChatTerminalView(),
                ),

                if (_isRightPanelVisible)
                  const VerticalDivider(width: 1, color: AppTheme.darkBorder),

                // 3. Right Panel (Code Editor, Saved Chats, Web View, RAG Knowledge)
                if (_isRightPanelVisible)
                  const Expanded(
                    flex: 4,
                    child: RightPanelContainer(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

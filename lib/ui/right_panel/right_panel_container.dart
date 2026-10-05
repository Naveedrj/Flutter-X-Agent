import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';
import '../center_panel/file_editor_view.dart';
import 'rag_inspector_view.dart';
import 'saved_chats_list.dart';
import 'web_preview_view.dart';

class RightPanelContainer extends StatefulWidget {
  const RightPanelContainer({super.key});

  @override
  State<RightPanelContainer> createState() => _RightPanelContainerState();
}

class _RightPanelContainerState extends State<RightPanelContainer> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final workspace = context.watch<WorkspaceProvider>();

    // Auto-switch to Editor tab if a file is clicked in the explorer
    if (workspace.currentOpenFilePath != null && workspace.isFileDirty && _tabController.index != 0) {
      _tabController.animateTo(0);
    }

    final hasWebPreview = chatProvider.activeSession?.webPreviewHtml != null;
    final hasOpenFile = workspace.currentOpenFilePath != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkBg,
        border: Border(left: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Column(
        children: [
          // Top Header Tabs
          Container(
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF131D30),
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 2.5,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 11.5),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.code_rounded, size: 14),
                      const SizedBox(width: 5),
                      Text(hasOpenFile ? 'Editor *' : 'Editor'),
                    ],
                  ),
                ),
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded, size: 14),
                      const SizedBox(width: 5),
                      Text('Saved (${chatProvider.sessions.length})'),
                    ],
                  ),
                ),
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language_rounded, size: 14),
                      const SizedBox(width: 5),
                      const Text('Web View'),
                      if (hasWebPreview) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accentCyan,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hub_outlined, size: 14),
                      const SizedBox(width: 5),
                      Text('RAG (${workspace.ragStats.totalChunks})'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                FileEditorView(),
                SavedChatsList(),
                WebPreviewView(),
                RagInspectorView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

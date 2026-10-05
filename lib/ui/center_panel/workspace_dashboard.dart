import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/rag_chunk.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';
import 'file_editor_view.dart';
import 'terminal_console_view.dart';

class WorkspaceDashboard extends StatefulWidget {
  const WorkspaceDashboard({super.key});

  @override
  State<WorkspaceDashboard> createState() => _WorkspaceDashboardState();
}

class _WorkspaceDashboardState extends State<WorkspaceDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _ragSearchController = TextEditingController();
  List<RagSearchResult> _ragSearchResults = [];
  bool _isSearchingRag = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ragSearchController.dispose();
    super.dispose();
  }

  Future<void> _performRagSearch() async {
    final query = _ragSearchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearchingRag = true);
    final workspace = context.read<WorkspaceProvider>();
    final results = await workspace.ragService.search(query, topK: 8);
    setState(() {
      _ragSearchResults = results;
      _isSearchingRag = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceProvider>();

    // Auto-switch to editor if file was opened
    if (workspace.currentOpenFilePath != null && _tabController.index != 0 && workspace.isFileDirty) {
      _tabController.animateTo(0);
    }

    return Container(
      color: AppTheme.darkBg,
      child: Column(
        children: [
          // Top Tab Bar
          Container(
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF131D30),
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 2.5,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 12.5),
              tabs: [
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.code_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(workspace.currentOpenFilePath != null ? 'Editor' : 'Code View'),
                    ],
                  ),
                ),
                Tab(
                  iconMargin: EdgeInsets.zero,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.terminal, size: 16),
                      const SizedBox(width: 6),
                      const Text('Terminal Output'),
                      if (workspace.isCommandRunning) ...[
                        const SizedBox(width: 6),
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentCyan),
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
                      const Icon(Icons.hub_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('RAG Knowledge (${workspace.ragStats.totalChunks})'),
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
              children: [
                // Tab 1: Editor
                const FileEditorView(),

                // Tab 2: Terminal
                const TerminalConsoleView(),

                // Tab 3: RAG Knowledge Inspector
                _buildRagInspector(workspace),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRagInspector(WorkspaceProvider workspace) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.darkBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ragSearchController,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Test RAG search query across indexed files (e.g. "authentication", "api client")...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                  ),
                  onSubmitted: (_) => _performRagSearch(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                icon: const Icon(Icons.saved_search, size: 18),
                label: const Text('Test RAG'),
                onPressed: _isSearchingRag ? null : _performRagSearch,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isSearchingRag)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: AppTheme.accentCyan),
              ),
            )
          else if (_ragSearchResults.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hub_outlined, size: 48, color: Colors.white.withOpacity(0.15)),
                    const SizedBox(height: 12),
                    Text(
                      'RAG Codebase Index (${workspace.ragStats.totalFiles} files, ${workspace.ragStats.totalChunks} chunks)',
                      style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'The AI Agent automatically retrieves context from these chunks when answering and writing code.',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _ragSearchResults.length,
                itemBuilder: (context, index) {
                  final res = _ragSearchResults[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description_outlined, size: 16, color: AppTheme.accentCyan),
                              const SizedBox(width: 6),
                              Text(
                                '${res.chunk.relativePath} (Lines ${res.chunk.startLine}-${res.chunk.endLine})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Score: ${res.score.toStringAsFixed(1)} (${res.matchReason})',
                                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.primaryLight),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: SelectableText(
                              res.chunk.content,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
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

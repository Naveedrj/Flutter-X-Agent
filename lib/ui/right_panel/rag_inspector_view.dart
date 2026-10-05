import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/rag_chunk.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';
import '../dialogs/rag_status_dialog.dart';

class RagInspectorView extends StatefulWidget {
  const RagInspectorView({super.key});

  @override
  State<RagInspectorView> createState() => _RagInspectorViewState();
}

class _RagInspectorViewState extends State<RagInspectorView> {
  final TextEditingController _ragSearchController = TextEditingController();
  List<RagSearchResult> _ragSearchResults = [];
  bool _isSearchingRag = false;

  @override
  void dispose() {
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

    return Container(
      color: AppTheme.darkBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF131D30),
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hub_outlined, size: 16, color: AppTheme.accentCyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'RAG KNOWLEDGE (${workspace.ragStats.totalChunks} chunks)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 16, color: Colors.white60),
                  tooltip: 'RAG Details',
                  onPressed: () {
                    showDialog(context: context, builder: (_) => const RagStatusDialog());
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.white60),
                  tooltip: 'Re-index Codebase',
                  onPressed: () => workspace.triggerRagReindex(),
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ragSearchController,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search indexed codebase snippets...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onSubmitted: (_) => _performRagSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: _isSearchingRag ? null : _performRagSearch,
                  child: const Text('Search', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),

          // Results or Empty State
          Expanded(
            child: _isSearchingRag
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
                : _ragSearchResults.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.manage_search_outlined, size: 40, color: Colors.white.withValues(alpha: 0.2)),
                              const SizedBox(height: 10),
                              Text(
                                '${workspace.ragStats.totalFiles} files indexed (${workspace.ragStats.totalChunks} chunks)',
                                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Type a query above to inspect what chunks get retrieved for the AI agent.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        itemCount: _ragSearchResults.length,
                        itemBuilder: (context, index) {
                          final res = _ragSearchResults[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: const Color(0xFF141D30),
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.code, size: 14, color: AppTheme.accentCyan),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${res.chunk.relativePath} (L${res.chunk.startLine}-${res.chunk.endLine})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                            fontSize: 11.5,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Score: ${res.score.toStringAsFixed(1)}',
                                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.primaryLight),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0C1220),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: SelectableText(
                                      res.chunk.content,
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: Colors.white70),
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

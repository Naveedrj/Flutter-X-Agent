import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../app_theme.dart';

class WebPreviewView extends StatefulWidget {
  const WebPreviewView({super.key});

  @override
  State<WebPreviewView> createState() => _WebPreviewViewState();
}

class _WebPreviewViewState extends State<WebPreviewView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _htmlEditController;
  bool _isManualEditing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _htmlEditController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _htmlEditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final activeSession = chatProvider.activeSession;
    final htmlContent = activeSession?.webPreviewHtml;

    if (htmlContent != null && !_isManualEditing && _htmlEditController.text != htmlContent) {
      _htmlEditController.text = htmlContent;
    }

    return Container(
      color: AppTheme.darkBg,
      child: Column(
        children: [
          // Sub Toolbar
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF131D30),
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.language_rounded, size: 16, color: AppTheme.accentCyan),
                const SizedBox(width: 8),
                const Text(
                  'WEB VIEW & ARTIFACT PREVIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                if (htmlContent != null && htmlContent.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.copy, size: 15, color: Colors.white60),
                    tooltip: 'Copy HTML',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: htmlContent));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('HTML copied to clipboard'), duration: Duration(seconds: 1)),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(_isManualEditing ? Icons.save : Icons.edit_note, size: 16, color: AppTheme.accentCyan),
                    tooltip: _isManualEditing ? 'Apply HTML' : 'Edit Source',
                    onPressed: () {
                      setState(() {
                        if (_isManualEditing) {
                          chatProvider.updateWebPreviewHtml(_htmlEditController.text);
                        }
                        _isManualEditing = !_isManualEditing;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

          // Main View or Empty State
          Expanded(
            child: htmlContent == null || htmlContent.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.web_asset_outlined, size: 48, color: Colors.white.withOpacity(0.15)),
                          const SizedBox(height: 12),
                          const Text(
                            'No Web Artifact in Active Chat',
                            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ask the Gemini Agent to generate a web component or HTML page:\n"Create a sleek dark dashboard in HTML/CSS"',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.auto_awesome, size: 15),
                            label: const Text('Load Demo Web Component', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              const sample = '''
<div style="font-family: system-ui, sans-serif; padding: 24px; background: #0f172a; color: #f8fafc; border-radius: 12px; border: 1px solid #334155;">
  <h2 style="color: #6366f1; margin-top: 0;">🚀 Agentic Codebase Dashboard</h2>
  <p style="color: #94a3b8; font-size: 14px;">Live preview rendered directly from the AI Agent.</p>
  <div style="display: flex; gap: 12px; margin-top: 16px;">
    <div style="flex: 1; padding: 14px; background: #1e293b; border-radius: 8px; border: 1px solid #334155;">
      <div style="font-size: 12px; color: #64748b;">TOTAL FILES</div>
      <div style="font-size: 24px; font-weight: bold; color: #38bdf8;">142</div>
    </div>
    <div style="flex: 1; padding: 14px; background: #1e293b; border-radius: 8px; border: 1px solid #334155;">
      <div style="font-size: 12px; color: #64748b;">RAG CHUNKS</div>
      <div style="font-size: 24px; font-weight: bold; color: #10b981;">580</div>
    </div>
    <div style="flex: 1; padding: 14px; background: #1e293b; border-radius: 8px; border: 1px solid #334155;">
      <div style="font-size: 12px; color: #64748b;">ACTIVE TOOLS</div>
      <div style="font-size: 24px; font-weight: bold; color: #f59e0b;">8 Tools</div>
    </div>
  </div>
</div>
''';
                              chatProvider.updateWebPreviewHtml(sample);
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : _isManualEditing
                    ? Container(
                        color: const Color(0xFF0C1220),
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _htmlEditController,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Color(0xFF38BDF8),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131D30),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.darkBorder),
                                ),
                                child: MarkdownBody(
                                  data: htmlContent,
                                  selectable: true,
                                  styleSheet: MarkdownStyleSheet(
                                    p: const TextStyle(fontSize: 13, color: Colors.white),
                                    h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'RAW HTML CODE:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0B101C),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.darkBorder),
                                ),
                                child: SelectableText(
                                  htmlContent,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

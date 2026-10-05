import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';

class FileEditorView extends StatefulWidget {
  const FileEditorView({super.key});

  @override
  State<FileEditorView> createState() => _FileEditorViewState();
}

class _FileEditorViewState extends State<FileEditorView> {
  late TextEditingController _textController;
  bool _isEditing = false;
  double _fontSize = 13.0;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _detectLanguage(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.dart':
        return 'dart';
      case '.js':
      case '.jsx':
        return 'javascript';
      case '.ts':
      case '.tsx':
        return 'typescript';
      case '.html':
        return 'htmlbars';
      case '.css':
        return 'css';
      case '.json':
        return 'json';
      case '.yaml':
      case '.yml':
        return 'yaml';
      case '.md':
        return 'markdown';
      case '.py':
        return 'python';
      case '.sh':
      case '.bash':
      case '.zsh':
        return 'bash';
      case '.xml':
        return 'xml';
      case '.sql':
        return 'sql';
      default:
        return 'plaintext';
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceProvider>();
    final currentPath = workspace.currentOpenFilePath;

    if (currentPath == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.code_rounded, size: 56, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 16),
            const Text(
              'No File Opened',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a file from the explorer on the left\nor prompt the AI Agent to generate/edit code.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.white.withOpacity(0.4)),
            ),
          ],
        ),
      );
    }

    if (_textController.text != workspace.currentFileContent && !_isEditing) {
      _textController.text = workspace.currentFileContent;
    }

    final filename = p.basename(currentPath);
    final relPath = workspace.workspaceService.getRelativePath(currentPath);
    final lang = _detectLanguage(currentPath);

    return Column(
      children: [
        // Editor Header / Tabs Bar
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF131D30),
            border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppTheme.darkBg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  border: Border(
                    top: BorderSide(color: AppTheme.primary, width: 2),
                    left: BorderSide(color: AppTheme.darkBorder),
                    right: BorderSide(color: AppTheme.darkBorder),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$filename${workspace.isFileDirty ? " *" : ""}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: workspace.isFileDirty ? AppTheme.warning : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  relPath,
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white.withOpacity(0.3)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Font size controls
              IconButton(
                icon: const Icon(Icons.remove, size: 14, color: Colors.white60),
                splashRadius: 10,
                tooltip: 'Decrease Font Size',
                onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(10.0, 20.0)),
              ),
              Text(
                '${_fontSize.toInt()}pt',
                style: const TextStyle(fontSize: 11, color: Colors.white54, fontFamily: 'monospace'),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 14, color: Colors.white60),
                splashRadius: 10,
                tooltip: 'Increase Font Size',
                onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(10.0, 20.0)),
              ),
              const SizedBox(width: 8),
              // Toggle Edit Mode vs Highlight View
              IconButton(
                icon: Icon(
                  _isEditing ? Icons.visibility : Icons.edit_note,
                  size: 18,
                  color: _isEditing ? AppTheme.accentCyan : Colors.white70,
                ),
                tooltip: _isEditing ? 'View Syntax Highlighting' : 'Edit Code',
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                    if (!_isEditing) {
                      workspace.updateEditorContent(_textController.text);
                    }
                  });
                },
              ),
              if (workspace.isFileDirty)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 28),
                  ),
                  icon: const Icon(Icons.save, size: 14),
                  label: const Text('Save', style: TextStyle(fontSize: 11)),
                  onPressed: () async {
                    workspace.updateEditorContent(_textController.text);
                    await workspace.saveCurrentFile();
                  },
                ),
            ],
          ),
        ),

        // Editor Body
        Expanded(
          child: _isEditing
              ? Container(
                  color: const Color(0xFF0D1424),
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: _fontSize,
                      color: const Color(0xFFF1F5F9),
                      height: 1.45,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      workspace.updateEditorContent(val);
                    },
                  ),
                )
              : Container(
                  color: const Color(0xFF0F172A),
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: HighlightView(
                        workspace.currentFileContent,
                        language: lang,
                        theme: atomOneDarkTheme,
                        padding: const EdgeInsets.all(16),
                        textStyle: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: _fontSize,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

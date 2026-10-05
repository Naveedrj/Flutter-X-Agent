import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/file_item.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';

class FileTreeView extends StatefulWidget {
  final List<FileItem> items;
  final int depth;

  const FileTreeView({
    super.key,
    required this.items,
    this.depth = 0,
  });

  @override
  State<FileTreeView> createState() => _FileTreeViewState();
}

class _FileTreeViewState extends State<FileTreeView> {
  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty && widget.depth == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No files in workspace',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: widget.depth > 0 ? const NeverScrollableScrollPhysics() : null,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return _FileTreeItemWidget(item: item, depth: widget.depth);
      },
    );
  }
}

class _FileTreeItemWidget extends StatefulWidget {
  final FileItem item;
  final int depth;

  const _FileTreeItemWidget({
    required this.item,
    required this.depth,
  });

  @override
  State<_FileTreeItemWidget> createState() => _FileTreeItemWidgetState();
}

class _FileTreeItemWidgetState extends State<_FileTreeItemWidget> {
  bool _isHovered = false;

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case '.dart':
        return Icons.flutter_dash;
      case '.js':
      case '.ts':
      case '.jsx':
      case '.tsx':
        return Icons.javascript_outlined;
      case '.html':
        return Icons.html_outlined;
      case '.css':
        return Icons.css_outlined;
      case '.json':
        return Icons.data_object;
      case '.yaml':
      case '.yml':
        return Icons.settings_applications_outlined;
      case '.md':
        return Icons.description_outlined;
      case '.py':
        return Icons.terminal_outlined;
      case '.sh':
      case '.zsh':
      case '.bash':
        return Icons.terminal;
      case '.png':
      case '.jpg':
      case '.svg':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getFileColor(String ext) {
    switch (ext) {
      case '.dart':
        return AppTheme.accentCyan;
      case '.js':
      case '.ts':
        return AppTheme.warning;
      case '.html':
        return Colors.orangeAccent;
      case '.css':
        return Colors.blueAccent;
      case '.json':
        return AppTheme.success;
      case '.yaml':
      case '.yml':
        return AppTheme.purple;
      case '.md':
        return AppTheme.primaryLight;
      case '.py':
        return Colors.yellow;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceProvider>();
    final isSelected = workspace.currentOpenFilePath == widget.item.path;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: InkWell(
            onTap: () {
              if (widget.item.isDirectory) {
                setState(() {
                  widget.item.isExpanded = !widget.item.isExpanded;
                });
              } else {
                workspace.openFile(widget.item.path);
              }
            },
            child: Container(
              height: 28,
              padding: EdgeInsets.only(left: 8.0 + (widget.depth * 14.0), right: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.2)
                    : (_isHovered ? AppTheme.darkHover : Colors.transparent),
                border: isSelected
                    ? const Border(left: BorderSide(color: AppTheme.primary, width: 2.5))
                    : null,
              ),
              child: Row(
                children: [
                  if (widget.item.isDirectory)
                    Icon(
                      widget.item.isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                      size: 16,
                      color: Colors.white54,
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 4),
                  Icon(
                    widget.item.isDirectory
                        ? (widget.item.isExpanded ? Icons.folder_open : Icons.folder)
                        : _getFileIcon(widget.item.extension),
                    size: 16,
                    color: widget.item.isDirectory
                        ? (_isHovered ? AppTheme.warning : const Color(0xFFFBBF24))
                        : _getFileColor(widget.item.extension),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.item.name,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isSelected ? Colors.white : (_isHovered ? Colors.white : Colors.white70),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isHovered)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 14, color: AppTheme.danger),
                      splashRadius: 12,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppTheme.darkSurface,
                            title: const Text('Delete Item', style: TextStyle(color: Colors.white)),
                            content: Text(
                              'Are you sure you want to delete "${widget.item.name}"?',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await workspace.deleteFileOrFolder(widget.item.path);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
        if (widget.item.isDirectory && widget.item.isExpanded && widget.item.children.isNotEmpty)
          FileTreeView(
            items: widget.item.children,
            depth: widget.depth + 1,
          ),
      ],
    );
  }
}

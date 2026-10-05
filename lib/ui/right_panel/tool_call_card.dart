import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/tool_call_log.dart';
import '../app_theme.dart';

class ToolCallCard extends StatefulWidget {
  final ToolCallLog toolLog;

  const ToolCallCard({super.key, required this.toolLog});

  @override
  State<ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<ToolCallCard> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // Default expand terminal commands
    if (widget.toolLog.toolName == 'execute_terminal_command') {
      _isExpanded = true;
    }
  }

  IconData _getToolIcon(String name) {
    switch (name) {
      case 'read_file':
        return Icons.menu_book_outlined;
      case 'write_file':
        return Icons.post_add_outlined;
      case 'edit_file':
        return Icons.edit_note_outlined;
      case 'move_file':
        return Icons.drive_file_move_outlined;
      case 'delete_file':
        return Icons.delete_outline;
      case 'list_directory':
        return Icons.folder_open_outlined;
      case 'execute_terminal_command':
        return Icons.terminal_rounded;
      case 'search_codebase':
        return Icons.manage_search_outlined;
      default:
        return Icons.handyman_outlined;
    }
  }

  Color _getStatusColor(ToolStatus status) {
    switch (status) {
      case ToolStatus.running:
        return AppTheme.warning;
      case ToolStatus.success:
        return AppTheme.success;
      case ToolStatus.failed:
        return AppTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.toolLog;
    final color = _getStatusColor(t.status);
    final isTerminal = t.toolName == 'execute_terminal_command';
    final commandText = (t.arguments['command'] ?? t.arguments['path'] ?? t.arguments['query'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: isTerminal ? const Color(0xFF0C1322) : const Color(0xFF141D30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTerminal ? AppTheme.accentCyan.withValues(alpha: 0.4) : color.withValues(alpha: 0.35),
          width: isTerminal ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(_getToolIcon(t.toolName), size: 16, color: isTerminal ? AppTheme.accentCyan : color),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isTerminal
                          ? '\$ $commandText'
                          : (t.stepDescription ?? t.toolName),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isTerminal ? AppTheme.accentCyan : Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (t.diffStats != null && t.diffStats!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: Text(
                        t.diffStats!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  if (t.status == ToolStatus.running)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.warning),
                    )
                  else if (t.status == ToolStatus.success)
                    const Icon(Icons.check_circle, size: 14, color: AppTheme.success)
                  else
                    const Icon(Icons.error_outline, size: 14, color: AppTheme.danger),
                  const SizedBox(width: 6),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Details / Terminal Output
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF090E1A),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                border: Border(top: BorderSide(color: AppTheme.darkBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isTerminal) ...[
                    const Text(
                      'ARGUMENTS:',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      t.argumentsFormatted,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.primaryLight),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isTerminal ? 'TERMINAL OUTPUT:' : 'RESULT OUTPUT:',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54),
                      ),
                      if (t.output != null && t.output!.isNotEmpty)
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: t.output!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Output copied to clipboard'), duration: Duration(seconds: 1)),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                              const SizedBox(width: 4),
                              Text(
                                'Copy Output',
                                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (t.status == ToolStatus.running)
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: const Row(
                        children: [
                          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentCyan)),
                          SizedBox(width: 8),
                          Text('Executing in workspace terminal...', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white60)),
                        ],
                      ),
                    )
                  else if (t.output != null && t.output!.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF060911),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          t.output!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.35,
                            color: t.status == ToolStatus.failed ? AppTheme.danger : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    )
                  else
                    const Text(
                      'No output returned.',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white38),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

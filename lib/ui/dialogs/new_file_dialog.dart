import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/workspace_provider.dart';
import '../app_theme.dart';

class NewFileDialog extends StatefulWidget {
  final bool isDirectory;
  final String? initialDir;

  const NewFileDialog({
    super.key,
    required this.isDirectory,
    this.initialDir,
  });

  @override
  State<NewFileDialog> createState() => _NewFileDialogState();
}

class _NewFileDialogState extends State<NewFileDialog> {
  late TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialDir != null && widget.initialDir!.isNotEmpty
          ? '${widget.initialDir}/'
          : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.read<WorkspaceProvider>();

    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    widget.isDirectory ? Icons.create_new_folder_outlined : Icons.note_add_outlined,
                    color: widget.isDirectory ? AppTheme.warning : AppTheme.primaryLight,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.isDirectory ? 'New Directory' : 'New File',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.isDirectory
                    ? 'Enter directory path relative to workspace root:'
                    : 'Enter file path relative to workspace root (e.g. lib/utils/helper.dart):',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: widget.isDirectory ? 'src/components' : 'src/main.dart',
                  prefixIcon: const Icon(Icons.subdirectory_arrow_right, size: 18),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a valid path';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        final path = _nameController.text.trim();
                        if (widget.isDirectory) {
                          await workspace.createNewFolder(path);
                        } else {
                          await workspace.createNewFile(path);
                        }
                        if (mounted) Navigator.of(context).pop();
                      }
                    },
                    child: Text(widget.isDirectory ? 'Create Folder' : 'Create File'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

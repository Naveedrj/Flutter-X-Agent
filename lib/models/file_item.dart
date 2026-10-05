import 'dart:io';
import 'package:path/path.dart' as p;

class FileItem {
  final String path;
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime modified;
  List<FileItem> children;
  bool isExpanded;

  FileItem({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.size = 0,
    DateTime? modified,
    List<FileItem>? children,
    this.isExpanded = false,
  })  : modified = modified ?? DateTime.now(),
        children = children ?? [];

  String get extension => p.extension(path).toLowerCase();

  String get formattedSize {
    if (isDirectory) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<FileItem> fromFileSystemEntity(FileSystemEntity entity) async {
    final stat = await entity.stat();
    final isDir = stat.type == FileSystemEntityType.directory;
    final name = p.basename(entity.path);

    return FileItem(
      path: entity.path,
      name: name,
      isDirectory: isDir,
      size: isDir ? 0 : stat.size,
      modified: stat.modified,
    );
  }
}

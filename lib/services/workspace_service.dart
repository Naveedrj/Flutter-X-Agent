import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/file_item.dart';

class WorkspaceService {
  String? rootPath;

  static const Set<String> ignoredDirectories = {
    '.git',
    'node_modules',
    'build',
    '.dart_tool',
    '.idea',
    '.vscode',
    'Pods',
    '.gradle',
    'dist',
    '.next',
    'target',
    '.flutter-plugins',
    '.flutter-plugins-dependencies',
  };

  static const Set<String> ignoredExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.ico',
    '.svg',
    '.mp4',
    '.mp3',
    '.pdf',
    '.zip',
    '.tar',
    '.gz',
    '.dylib',
    '.so',
    '.dll',
    '.exe',
    '.bin',
    '.lock',
  };

  void setRoot(String path) {
    rootPath = path;
  }

  String resolvePath(String targetPath) {
    if (rootPath == null) return targetPath;
    if (p.isAbsolute(targetPath)) return targetPath;
    return p.normalize(p.join(rootPath!, targetPath));
  }

  String getRelativePath(String fullPath) {
    if (rootPath == null) return fullPath;
    try {
      return p.relative(fullPath, from: rootPath);
    } catch (_) {
      return fullPath;
    }
  }

  Future<List<FileItem>> loadDirectoryTree(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];

    final List<FileItem> items = [];
    try {
      final entities = await dir.list(followLinks: false).toList();
      entities.sort((a, b) {
        final isDirA = a is Directory;
        final isDirB = b is Directory;
        if (isDirA != isDirB) {
          return isDirA ? -1 : 1;
        }
        return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
      });

      for (final entity in entities) {
        final name = p.basename(entity.path);
        if (name.startsWith('.') && name != '.env' && name != '.gitignore') {
          if (ignoredDirectories.contains(name)) continue;
        }
        if (ignoredDirectories.contains(name)) continue;

        final isDir = entity is Directory;
        final stat = await entity.stat();

        final item = FileItem(
          path: entity.path,
          name: name,
          isDirectory: isDir,
          size: isDir ? 0 : stat.size,
          modified: stat.modified,
          isExpanded: false,
        );

        if (isDir) {
          // prefetch 1st level children
          item.children = await loadDirectoryTree(entity.path);
        }

        items.add(item);
      }
    } catch (e) {
      // ignore permissions error on single directory
    }
    return items;
  }

  Future<String> readFile(String targetPath, {int? startLine, int? endLine}) async {
    final fullPath = resolvePath(targetPath);
    final file = File(fullPath);

    if (!await file.exists()) {
      throw Exception('File not found: $targetPath (resolved: $fullPath)');
    }

    // Check size limit (< 5MB for text reading)
    final length = await file.length();
    if (length > 5 * 1024 * 1024) {
      throw Exception('File too large to read directly (${(length / (1024 * 1024)).toStringAsFixed(2)}MB). Use line range or smaller files.');
    }

    final content = await file.readAsString();
    if (startLine == null && endLine == null) {
      return content;
    }

    final lines = content.split('\n');
    final s = (startLine ?? 1).clamp(1, lines.isEmpty ? 1 : lines.length);
    final e = (endLine ?? lines.length).clamp(s, lines.isEmpty ? 1 : lines.length);

    final sliced = lines.sublist(s - 1, e);
    final buffer = StringBuffer();
    for (int i = 0; i < sliced.length; i++) {
      buffer.writeln('${s + i}: ${sliced[i]}');
    }
    return buffer.toString();
  }

  Future<String> writeFile(String targetPath, String content) async {
    final fullPath = resolvePath(targetPath);
    final file = File(fullPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return 'Successfully wrote ${content.length} characters to ${getRelativePath(fullPath)}';
  }

  Future<String> editFile(
    String targetPath,
    String targetContent,
    String replacementContent,
  ) async {
    final fullPath = resolvePath(targetPath);
    final file = File(fullPath);

    if (!await file.exists()) {
      throw Exception('File not found: $targetPath');
    }

    final original = await file.readAsString();
    if (!original.contains(targetContent)) {
      throw Exception('targetContent not found in $targetPath. Make sure target content matches exactly.');
    }

    final updated = original.replaceFirst(targetContent, replacementContent);
    await file.writeAsString(updated);
    return 'Successfully replaced snippet in ${getRelativePath(fullPath)}';
  }

  Future<String> moveFile(String sourcePath, String destPath) async {
    final fullSource = resolvePath(sourcePath);
    final fullDest = resolvePath(destPath);

    final isDir = await FileSystemEntity.isDirectory(fullSource);
    if (isDir) {
      final dir = Directory(fullSource);
      if (!await dir.exists()) throw Exception('Source directory not found: $sourcePath');
      await dir.parent.create(recursive: true);
      await dir.rename(fullDest);
      return 'Successfully moved directory $sourcePath to $destPath';
    } else {
      final file = File(fullSource);
      if (!await file.exists()) throw Exception('Source file not found: $sourcePath');
      await File(fullDest).parent.create(recursive: true);
      await file.rename(fullDest);
      return 'Successfully moved file $sourcePath to $destPath';
    }
  }

  Future<String> deleteFile(String targetPath) async {
    final fullPath = resolvePath(targetPath);
    final isDir = await FileSystemEntity.isDirectory(fullPath);
    if (isDir) {
      final dir = Directory(fullPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return 'Successfully deleted directory $targetPath';
      }
    } else {
      final file = File(fullPath);
      if (await file.exists()) {
        await file.delete();
        return 'Successfully deleted file $targetPath';
      }
    }
    throw Exception('Target does not exist: $targetPath');
  }

  Future<List<String>> listDirectory(String targetPath) async {
    final fullPath = resolvePath(targetPath);
    final dir = Directory(fullPath);
    if (!await dir.exists()) {
      throw Exception('Directory not found: $targetPath');
    }

    final entities = await dir.list().toList();
    final List<String> results = [];
    for (final e in entities) {
      final isDir = e is Directory;
      final rel = getRelativePath(e.path);
      results.add('${isDir ? "[DIR] " : "[FILE]"} $rel');
    }
    return results;
  }

  Future<List<File>> getAllTextFiles({int maxFiles = 300}) async {
    if (rootPath == null) return [];
    final rootDir = Directory(rootPath!);
    if (!await rootDir.exists()) return [];

    final List<File> files = [];
    await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
      if (files.length >= maxFiles) break;
      if (entity is File) {
        final filename = p.basename(entity.path);
        final ext = p.extension(entity.path).toLowerCase();

        // Check if path contains ignored folder
        final parts = p.split(getRelativePath(entity.path));
        final hasIgnored = parts.any((part) => ignoredDirectories.contains(part));
        if (hasIgnored) continue;

        if (ignoredExtensions.contains(ext)) continue;
        if (filename.startsWith('.') && filename != '.env' && filename != '.gitignore') continue;

        try {
          final stat = await entity.stat();
          if (stat.size > 1024 * 1024) continue; // Skip files > 1MB for indexing
          files.add(entity);
        } catch (_) {}
      }
    }
    return files;
  }
}

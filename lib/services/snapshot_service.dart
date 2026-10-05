import 'dart:io';
import '../models/file_diff.dart';
import '../models/workspace_snapshot.dart';
import 'diff_service.dart';
import 'workspace_service.dart';

class SnapshotService {
  final WorkspaceService workspaceService;
  final Map<String, WorkspaceTurnSnapshot> _snapshots = {};
  final List<FileDiff> _recentDiffs = [];

  SnapshotService({required this.workspaceService});

  List<FileDiff> get recentDiffs => List.unmodifiable(_recentDiffs);

  Future<void> captureFileBeforeEdit(String turnId, String targetPath, {String prompt = ''}) async {
    final fullPath = workspaceService.resolvePath(targetPath);
    final file = File(fullPath);
    final exists = await file.exists();
    String? content;
    if (exists) {
      try {
        content = await file.readAsString();
      } catch (_) {}
    }

    final snapshot = _snapshots.putIfAbsent(
      turnId,
      () => WorkspaceTurnSnapshot(
        turnId: turnId,
        prompt: prompt,
        fileSnapshots: {},
      ),
    );

    // Capture original state only on the first mutation of this file in this turn
    if (!snapshot.fileSnapshots.containsKey(targetPath)) {
      snapshot.fileSnapshots[targetPath] = FileSnapshot(
        path: targetPath,
        content: content,
        existed: exists,
      );
    }
  }

  Future<void> recordFileDiff(String targetPath, String oldContent, String newContent) async {
    final diff = DiffService.computeDiff(targetPath, oldContent, newContent);
    _recentDiffs.removeWhere((d) => d.filePath == targetPath);
    _recentDiffs.insert(0, diff);
    if (_recentDiffs.length > 20) {
      _recentDiffs.removeLast();
    }
  }

  bool canRollback(String turnId) {
    return _snapshots.containsKey(turnId) && _snapshots[turnId]!.fileSnapshots.isNotEmpty;
  }

  Future<int> rollbackTurn(String turnId) async {
    final snapshot = _snapshots[turnId];
    if (snapshot == null) return 0;

    int restoredCount = 0;
    for (final entry in snapshot.fileSnapshots.entries) {
      final targetPath = entry.key;
      final fileSnap = entry.value;
      final fullPath = workspaceService.resolvePath(targetPath);
      final file = File(fullPath);

      if (fileSnap.existed && fileSnap.content != null) {
        // Restore previous content
        await file.parent.create(recursive: true);
        await file.writeAsString(fileSnap.content!);
        restoredCount++;
      } else {
        // File was newly created in this turn, delete it
        if (await file.exists()) {
          await file.delete();
          restoredCount++;
        }
      }
    }

    // Remove snapshot once rolled back
    _snapshots.remove(turnId);
    return restoredCount;
  }

  Future<void> revertSingleFile(String targetPath, String originalContent) async {
    final fullPath = workspaceService.resolvePath(targetPath);
    final file = File(fullPath);
    if (originalContent.isEmpty) {
      if (await file.exists()) await file.delete();
    } else {
      await file.writeAsString(originalContent);
    }
    _recentDiffs.removeWhere((d) => d.filePath == targetPath);
  }
}

class FileSnapshot {
  final String path;
  final String? content; // null if file didn't exist prior to turn
  final bool existed;

  FileSnapshot({
    required this.path,
    required this.content,
    required this.existed,
  });
}

class WorkspaceTurnSnapshot {
  final String turnId;
  final String prompt;
  final Map<String, FileSnapshot> fileSnapshots; // relativePath -> FileSnapshot
  final DateTime timestamp;

  WorkspaceTurnSnapshot({
    required this.turnId,
    required this.prompt,
    required this.fileSnapshots,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

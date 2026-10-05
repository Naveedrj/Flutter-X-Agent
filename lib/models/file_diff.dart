enum DiffLineType {
  added,
  deleted,
  unchanged,
}

class DiffLine {
  final DiffLineType type;
  final String text;
  final int? oldLineNumber;
  final int? newLineNumber;

  DiffLine({
    required this.type,
    required this.text,
    this.oldLineNumber,
    this.newLineNumber,
  });
}

class FileDiff {
  final String filePath;
  final String originalContent;
  final String newContent;
  final List<DiffLine> lines;
  final int additions;
  final int deletions;
  final DateTime timestamp;

  FileDiff({
    required this.filePath,
    required this.originalContent,
    required this.newContent,
    required this.lines,
    required this.additions,
    required this.deletions,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

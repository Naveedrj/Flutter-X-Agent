import '../models/file_diff.dart';

class DiffService {
  static FileDiff computeDiff(String filePath, String oldText, String newText) {
    final oldLines = oldText.isEmpty ? <String>[] : oldText.split('\n');
    final newLines = newText.isEmpty ? <String>[] : newText.split('\n');

    final diffLines = <DiffLine>[];
    int additions = 0;
    int deletions = 0;

    // LCS-based line diff algorithm
    final n = oldLines.length;
    final m = newLines.length;

    // Compute LCS matrix
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < m; j++) {
        if (oldLines[i] == newLines[j]) {
          dp[i + 1][j + 1] = dp[i][j] + 1;
        } else {
          dp[i + 1][j + 1] = dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1];
        }
      }
    }

    // Backtrack to build diff sequence
    int i = n;
    int j = m;
    final reversedList = <DiffLine>[];

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1]) {
        reversedList.add(DiffLine(
          type: DiffLineType.unchanged,
          text: oldLines[i - 1],
          oldLineNumber: i,
          newLineNumber: j,
        ));
        i--;
        j--;
      } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        reversedList.add(DiffLine(
          type: DiffLineType.added,
          text: newLines[j - 1],
          newLineNumber: j,
        ));
        additions++;
        j--;
      } else if (i > 0 && (j == 0 || dp[i][j - 1] < dp[i - 1][j])) {
        reversedList.add(DiffLine(
          type: DiffLineType.deleted,
          text: oldLines[i - 1],
          oldLineNumber: i,
        ));
        deletions++;
        i--;
      }
    }

    diffLines.addAll(reversedList.reversed);

    return FileDiff(
      filePath: filePath,
      originalContent: oldText,
      newContent: newText,
      lines: diffLines,
      additions: additions,
      deletions: deletions,
    );
  }
}

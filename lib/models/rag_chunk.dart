class RagChunk {
  final String id;
  final String relativePath;
  final String fullPath;
  final int startLine;
  final int endLine;
  final String content;
  List<double>? embedding;

  RagChunk({
    required this.id,
    required this.relativePath,
    required this.fullPath,
    required this.startLine,
    required this.endLine,
    required this.content,
    this.embedding,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'relativePath': relativePath,
        'fullPath': fullPath,
        'startLine': startLine,
        'endLine': endLine,
        'content': content,
        'embedding': embedding,
      };

  factory RagChunk.fromJson(Map<String, dynamic> json) => RagChunk(
        id: json['id'] as String,
        relativePath: json['relativePath'] as String,
        fullPath: json['fullPath'] as String,
        startLine: json['startLine'] as int,
        endLine: json['endLine'] as int,
        content: json['content'] as String,
        embedding: (json['embedding'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
      );
}

class RagSearchResult {
  final RagChunk chunk;
  final double score;
  final String matchReason;

  RagSearchResult({
    required this.chunk,
    required this.score,
    required this.matchReason,
  });
}

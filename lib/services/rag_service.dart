import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../models/rag_chunk.dart';
import 'workspace_service.dart';

class RagIndexStats {
  final int totalFiles;
  final int totalChunks;
  final DateTime lastIndexed;
  final bool isIndexing;
  final String? currentAction;

  RagIndexStats({
    required this.totalFiles,
    required this.totalChunks,
    required this.lastIndexed,
    this.isIndexing = false,
    this.currentAction,
  });
}

class RagService {
  final WorkspaceService workspaceService;
  final List<RagChunk> _chunks = [];
  final Map<String, double> _idfMap = {};
  bool _isIndexing = false;

  final _statsController = StreamController<RagIndexStats>.broadcast();
  Stream<RagIndexStats> get statsStream => _statsController.stream;

  RagIndexStats _currentStats = RagIndexStats(
    totalFiles: 0,
    totalChunks: 0,
    lastIndexed: DateTime.now(),
  );

  RagIndexStats get currentStats => _currentStats;
  List<RagChunk> get chunks => List.unmodifiable(_chunks);

  RagService({required this.workspaceService});

  void _emitStats({String? action, bool? isIndexing}) {
    _currentStats = RagIndexStats(
      totalFiles: _chunks.map((c) => c.fullPath).toSet().length,
      totalChunks: _chunks.length,
      lastIndexed: DateTime.now(),
      isIndexing: isIndexing ?? _isIndexing,
      currentAction: action,
    );
    _statsController.add(_currentStats);
  }

  Future<void> indexWorkspace({String? geminiApiKey}) async {
    if (workspaceService.rootPath == null || _isIndexing) return;
    _isIndexing = true;
    _emitStats(action: 'Scanning workspace files...', isIndexing: true);

    _chunks.clear();
    _idfMap.clear();

    try {
      final files = await workspaceService.getAllTextFiles(maxFiles: 500);
      int processedFiles = 0;

      for (final file in files) {
        processedFiles++;
        final relPath = workspaceService.getRelativePath(file.path);
        _emitStats(
          action: 'Indexing ($processedFiles/${files.length}): $relPath',
          isIndexing: true,
        );

        try {
          final content = await file.readAsString();
          final fileChunks = _chunkFile(file.path, relPath, content);
          _chunks.addAll(fileChunks);
        } catch (_) {
          // Skip binary or unreadable file
        }
      }

      // Compute IDF map for lexical BM25/TF-IDF search
      _computeIdf();

      // If valid Gemini API key is provided and chunks <= 80, optionally batch embed
      if (geminiApiKey != null &&
          geminiApiKey.isNotEmpty &&
          geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE' &&
          _chunks.isNotEmpty &&
          _chunks.length <= 100) {
        _emitStats(action: 'Generating semantic embeddings...', isIndexing: true);
        await _generateEmbeddingsBatch(geminiApiKey);
      }

      _isIndexing = false;
      _emitStats(action: 'Indexing complete!', isIndexing: false);
    } catch (e) {
      _isIndexing = false;
      _emitStats(action: 'Indexing failed: $e', isIndexing: false);
    }
  }

  List<RagChunk> _chunkFile(String fullPath, String relPath, String content) {
    final lines = content.split('\n');
    if (lines.isEmpty) return [];

    final List<RagChunk> result = [];
    const chunkSize = 60;
    const overlap = 15;

    int chunkIndex = 0;
    for (int i = 0; i < lines.length; i += (chunkSize - overlap)) {
      final end = min(i + chunkSize, lines.length);
      final chunkLines = lines.sublist(i, end);
      final chunkContent = chunkLines.join('\n');

      if (chunkContent.trim().isNotEmpty) {
        result.add(RagChunk(
          id: '${relPath}_$chunkIndex',
          relativePath: relPath,
          fullPath: fullPath,
          startLine: i + 1,
          endLine: end,
          content: chunkContent,
        ));
        chunkIndex++;
      }

      if (end >= lines.length) break;
    }
    return result;
  }

  void _computeIdf() {
    final totalDocs = _chunks.length;
    if (totalDocs == 0) return;

    final docFreq = <String, int>{};
    for (final chunk in _chunks) {
      final tokens = _tokenize('${chunk.relativePath}\n${chunk.content}');
      for (final t in tokens.toSet()) {
        docFreq[t] = (docFreq[t] ?? 0) + 1;
      }
    }

    docFreq.forEach((token, count) {
      _idfMap[token] = log((totalDocs - count + 0.5) / (count + 0.5) + 1.0);
    });
  }

  Set<String> _tokenize(String text) {
    // Split camelCase, snake_case, and non-alphanumeric
    final cleaned = text.replaceAll(RegExp(r'([a-z])([A-Z])'), r'$1 $2');
    final tokens = cleaned
        .toLowerCase()
        .split(RegExp(r'[^a-zA-Z0-9_]'))
        .where((t) => t.length >= 2)
        .toSet();
    return tokens;
  }

  Future<List<RagSearchResult>> search(String query, {int topK = 5, String? geminiApiKey}) async {
    if (_chunks.isEmpty) return [];

    final queryTokens = _tokenize(query);
    if (queryTokens.isEmpty) return [];

    final results = <RagSearchResult>[];

    // Optional: If Gemini embeddings exist on chunks and API key is provided
    List<double>? queryEmbedding;
    if (geminiApiKey != null &&
        geminiApiKey.isNotEmpty &&
        geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE' &&
        _chunks.any((c) => c.embedding != null)) {
      queryEmbedding = await _fetchEmbedding(query, geminiApiKey);
    }

    for (final chunk in _chunks) {
      double score = 0.0;
      final matchedTerms = <String>[];

      // 1. Path keyword match bonus
      final pathTokens = _tokenize(chunk.relativePath);
      for (final qt in queryTokens) {
        if (pathTokens.contains(qt)) {
          score += 3.5;
          matchedTerms.add('path:$qt');
        }
      }

      // 2. Content TF-IDF score
      final chunkTokens = _tokenize(chunk.content);
      for (final qt in queryTokens) {
        if (chunkTokens.contains(qt)) {
          final idf = _idfMap[qt] ?? 1.0;
          score += 1.0 * idf;
          matchedTerms.add(qt);
        }
      }

      // 3. Exact phrase match bonus
      if (chunk.content.toLowerCase().contains(query.toLowerCase())) {
        score += 4.0;
        matchedTerms.add('exact_phrase');
      }

      // 4. Vector Cosine Similarity (if available)
      if (queryEmbedding != null && chunk.embedding != null) {
        final cosSim = _cosineSimilarity(queryEmbedding, chunk.embedding!);
        if (cosSim > 0.6) {
          score += cosSim * 6.0;
          matchedTerms.add('semantic(${(cosSim * 100).toInt()}%)');
        }
      }

      if (score > 0.5) {
        results.add(RagSearchResult(
          chunk: chunk,
          score: score,
          matchReason: matchedTerms.take(4).join(', '),
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(topK).toList();
  }

  String formatRagContext(List<RagSearchResult> results) {
    if (results.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('=== RELEVANT CODEBASE CONTEXT (RAG Retrieval) ===');
    for (int i = 0; i < results.length; i++) {
      final res = results[i];
      buffer.writeln('\n[Source ${i + 1}: ${res.chunk.relativePath} (Lines ${res.chunk.startLine}-${res.chunk.endLine}) | Match: ${res.matchReason}]');
      buffer.writeln('```');
      buffer.writeln(res.chunk.content);
      buffer.writeln('```');
    }
    buffer.writeln('=== END OF CODEBASE CONTEXT ===\n');
    return buffer.toString();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  Future<List<double>?> _fetchEmbedding(String text, String apiKey) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=$apiKey',
      );
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'models/text-embedding-004',
          'content': {
            'parts': [
              {'text': text.substring(0, min(text.length, 2048))}
            ]
          }
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final values = data['embedding']?['values'] as List<dynamic>?;
        return values?.map((v) => (v as num).toDouble()).toList();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _generateEmbeddingsBatch(String apiKey) async {
    for (final chunk in _chunks) {
      if (chunk.embedding != null) continue;
      final preview = '${chunk.relativePath}\n${chunk.content}';
      final emb = await _fetchEmbedding(preview, apiKey);
      if (emb != null) {
        chunk.embedding = emb;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void dispose() {
    _statsController.close();
  }
}

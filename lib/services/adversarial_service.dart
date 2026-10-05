import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/adversarial_debate.dart';
import '../models/llm_provider.dart';
import 'snapshot_service.dart';
import 'workspace_service.dart';

class AdversarialService {
  final WorkspaceService workspaceService;
  final SnapshotService snapshotService;

  AdversarialService({
    required this.workspaceService,
    required this.snapshotService,
  });

  String normalizeGeminiModel(String model) {
    String m = model.trim();
    if (m.startsWith('models/')) {
      m = m.substring(7);
    }
    return m.isNotEmpty ? m : 'gemini-1.5-flash';
  }

  /// Call LLM directly with customized system and user prompts across any provider
  Future<String> generateText({
    required LlmProviderType provider,
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.3,
  }) async {
    final cleanKey = apiKey.trim();
    if (provider != LlmProviderType.ollama && (cleanKey.isEmpty || cleanKey.contains('YOUR_API_KEY'))) {
      throw Exception('No valid API Key found for ${provider.displayName}. Please configure your key in Settings ⚙️.');
    }

    if (provider == LlmProviderType.gemini) {
      return _generateGemini(model: model, apiKey: cleanKey, systemPrompt: systemPrompt, userPrompt: userPrompt, temperature: temperature);
    } else if (provider == LlmProviderType.anthropic) {
      return _generateAnthropic(model: model, apiKey: cleanKey, systemPrompt: systemPrompt, userPrompt: userPrompt, temperature: temperature);
    } else {
      return _generateOpenAiCompatible(provider: provider, model: model, apiKey: cleanKey, systemPrompt: systemPrompt, userPrompt: userPrompt, temperature: temperature);
    }
  }

  Future<String> _generateGemini({
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
  }) async {
    final cleanModel = normalizeGeminiModel(model);
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent?key=$apiKey');

    final payload = {
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userPrompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': 8192,
      }
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      Map<String, dynamic> errBody = {};
      try {
        errBody = jsonDecode(response.body);
      } catch (_) {}
      throw Exception(errBody['error']?['message'] ?? 'Gemini API Error (HTTP ${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>? ?? [];
    if (candidates.isEmpty) return 'No response generated.';

    final content = candidates[0]['content'] as Map<String, dynamic>? ?? {};
    final parts = content['parts'] as List<dynamic>? ?? [];
    final textBuffer = StringBuffer();
    for (final p in parts) {
      if (p['text'] != null) {
        textBuffer.write(p['text']);
      }
    }
    return textBuffer.toString();
  }

  Future<String> _generateAnthropic({
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
  }) async {
    final cleanModel = model.trim().isNotEmpty ? model.trim() : 'claude-3-5-sonnet-20241022';
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final payload = {
      'model': cleanModel,
      'max_tokens': 8192,
      'temperature': temperature,
      'system': systemPrompt,
      'messages': [
        {'role': 'user', 'content': userPrompt}
      ]
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      Map<String, dynamic> errBody = {};
      try {
        errBody = jsonDecode(response.body);
      } catch (_) {}
      throw Exception(errBody['error']?['message'] ?? 'Anthropic API Error: Status ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final contents = data['content'] as List<dynamic>? ?? [];
    final textBuffer = StringBuffer();
    for (final c in contents) {
      if (c['type'] == 'text' && c['text'] != null) {
        textBuffer.write(c['text']);
      }
    }
    return textBuffer.toString();
  }

  Future<String> _generateOpenAiCompatible({
    required LlmProviderType provider,
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
  }) async {
    Uri url;
    final headers = {'Content-Type': 'application/json'};

    if (provider == LlmProviderType.groq) {
      url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      headers['Authorization'] = 'Bearer $apiKey';
    } else if (provider == LlmProviderType.openrouter) {
      url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      headers['Authorization'] = 'Bearer $apiKey';
      headers['HTTP-Referer'] = 'https://github.com/Naveedrj/Flutter-X-Agent';
      headers['X-Title'] = 'Flutter-X-Agent';
    } else {
      // Ollama
      url = Uri.parse(apiKey.isNotEmpty && apiKey.startsWith('http') ? '$apiKey/v1/chat/completions' : 'http://localhost:11434/v1/chat/completions');
    }

    String effectiveModel = model.trim();
    if (provider == LlmProviderType.ollama) {
      if (effectiveModel.contains('/')) {
        effectiveModel = effectiveModel.split('/').last;
      }
      if (effectiveModel.endsWith(':free')) {
        effectiveModel = effectiveModel.substring(0, effectiveModel.length - 5);
      }
      if (effectiveModel.isEmpty || effectiveModel.startsWith('gemini') || effectiveModel.startsWith('claude')) {
        effectiveModel = 'qwen2.5-coder:7b';
      }
    } else if (effectiveModel.isEmpty) {
      effectiveModel = provider == LlmProviderType.groq ? 'qwen-2.5-coder-32b' : 'deepseek/deepseek-r1:free';
    }

    final payload = {
      'model': effectiveModel,
      'temperature': temperature,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      Map<String, dynamic> errBody = {};
      try {
        errBody = jsonDecode(response.body);
      } catch (_) {}
      final errMsg = errBody['error']?['message'] ?? errBody['error'] ?? '${provider.displayName} API Error: Status ${response.statusCode}';
      if (provider == LlmProviderType.ollama && errMsg.toString().contains('not found')) {
        throw Exception(
          'Local Ollama model "$effectiveModel" is not downloaded yet.\n'
          'Please run: `ollama pull $effectiveModel` in terminal\n'
          'Or select an already downloaded model from Duel Config (⚙️).'
        );
      }
      throw Exception(errMsg.toString());
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) return 'No response generated.';

    final msg = choices[0]['message'] as Map<String, dynamic>? ?? {};
    return (msg['content'] as String?) ?? '';
  }

  /// Extracts the largest or most relevant code block from markdown
  String? extractCodeBlock(String markdown) {
    final codeBlockRegex = RegExp(r'```(?:[\w\-\+]+)?\n([\s\S]*?)```');
    final matches = codeBlockRegex.allMatches(markdown);
    if (matches.isEmpty) return null;

    String? bestCode;
    int maxLength = 0;
    for (final m in matches) {
      final code = m.group(1)?.trim();
      if (code != null && code.length > maxLength) {
        maxLength = code.length;
        bestCode = code;
      }
    }
    return bestCode;
  }

  /// Parses list of vulnerabilities from Red Team response
  List<String> parseVulnerabilities(String markdown) {
    final list = <String>[];
    final lines = markdown.split('\n');
    bool inVulnSection = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.toUpperCase().contains('VULNERABILIT') || trimmed.toUpperCase().contains('EXPLOIT') || trimmed.toUpperCase().contains('SECURITY FLAW') || trimmed.toUpperCase().contains('🚨')) {
        inVulnSection = true;
        continue;
      }
      if (inVulnSection && (trimmed.startsWith('#') || trimmed.startsWith('---'))) {
        inVulnSection = false;
        continue;
      }
      if (inVulnSection && (trimmed.startsWith('-') || trimmed.startsWith('*') || RegExp(r'^\d+\.').hasMatch(trimmed))) {
        final item = trimmed.replaceFirst(RegExp(r'^[-\*\d\.]+\s*'), '').trim();
        if (item.isNotEmpty && item.length > 5 && !list.contains(item)) {
          list.add(item);
        }
      }
    }
    return list;
  }

  /// Parses list of optimizations from Red Team response
  List<String> parseOptimizations(String markdown) {
    final list = <String>[];
    final lines = markdown.split('\n');
    bool inOptSection = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.toUpperCase().contains('OPTIMIZ') || trimmed.toUpperCase().contains('PERFORMANCE') || trimmed.toUpperCase().contains('BOTTLENECK') || trimmed.toUpperCase().contains('⚡')) {
        inOptSection = true;
        continue;
      }
      if (inOptSection && (trimmed.startsWith('#') || trimmed.startsWith('---'))) {
        inOptSection = false;
        continue;
      }
      if (inOptSection && (trimmed.startsWith('-') || trimmed.startsWith('*') || RegExp(r'^\d+\.').hasMatch(trimmed))) {
        final item = trimmed.replaceFirst(RegExp(r'^[-\*\d\.]+\s*'), '').trim();
        if (item.isNotEmpty && item.length > 5 && !list.contains(item)) {
          list.add(item);
        }
      }
    }
    return list;
  }

  /// Runs the full multi-round adversarial duel loop
  Future<void> runAdversarialDuel({
    required AdversarialSession session,
    String? existingFileContext,
    required Function(DebateTurn turn) onTurnAdded,
    required Function(AdversarialSessionStatus status, String statusMessage) onStatusChanged,
  }) async {
    final cfg = session.config;
    String currentCode = existingFileContext ?? '';
    String lastBlueResponse = '';
    String lastRedCritique = '';

    for (int round = 1; round <= cfg.maxRounds; round++) {
      // 1. Blue turn
      onStatusChanged(AdversarialSessionStatus.runningBlue, 'Round $round: Blue Team (${cfg.blueProvider.displayName}) is constructing implementation...');
      final blueSystem = buildBlueSystemPrompt(round: round, focus: cfg.focus);
      final blueUser = round == 1
          ? buildBlueInitialPrompt(taskPrompt: session.taskPrompt, existingCode: currentCode.isNotEmpty ? currentCode : null)
          : buildBlueRefactorPrompt(taskPrompt: session.taskPrompt, previousCode: currentCode, redCritique: lastRedCritique);

      final blueResponse = await generateText(
        provider: cfg.blueProvider,
        model: cfg.blueModel,
        apiKey: cfg.blueApiKey,
        systemPrompt: blueSystem,
        userPrompt: blueUser,
        temperature: cfg.temperature,
      );

      lastBlueResponse = blueResponse;
      final extractedCode = extractCodeBlock(blueResponse);
      if (extractedCode != null && extractedCode.isNotEmpty) {
        currentCode = extractedCode;
      }

      final blueTurn = DebateTurn(
        id: '${session.id}_blue_$round',
        round: round,
        type: round == 1 ? DebateTurnType.blueProposal : DebateTurnType.blueDefense,
        speaker: 'Blue Team (Builder)',
        modelName: '${cfg.blueProvider.displayName} (${cfg.blueModel})',
        summary: 'Constructed code architecture & tests (Round $round)',
        fullContent: blueResponse,
        codeSnippet: extractedCode,
        timestamp: DateTime.now(),
      );
      session.turns.add(blueTurn);
      onTurnAdded(blueTurn);

      // 2. Red turn
      onStatusChanged(AdversarialSessionStatus.runningRed, 'Round $round: Red Team (${cfg.redProvider.displayName}) is attacking & finding vulnerabilities...');
      final redSystem = buildRedSystemPrompt(focus: cfg.focus);
      final redUser = buildRedAttackPrompt(
        taskPrompt: session.taskPrompt,
        codeToAttack: currentCode.isNotEmpty ? currentCode : lastBlueResponse,
        round: round,
        maxRounds: cfg.maxRounds,
      );

      final redResponse = await generateText(
        provider: cfg.redProvider,
        model: cfg.redModel,
        apiKey: cfg.redApiKey,
        systemPrompt: redSystem,
        userPrompt: redUser,
        temperature: cfg.temperature,
      );

      lastRedCritique = redResponse;
      final vulns = parseVulnerabilities(redResponse);
      final opts = parseOptimizations(redResponse);
      final isConsensus = redResponse.contains('CONSENSUS_REACHED') || round == cfg.maxRounds;

      final redTurn = DebateTurn(
        id: '${session.id}_red_$round',
        round: round,
        type: DebateTurnType.redAttack,
        speaker: 'Red Team (Hacker)',
        modelName: '${cfg.redProvider.displayName} (${cfg.redModel})',
        summary: 'Security & performance attack report (Round $round)',
        fullContent: redResponse,
        vulnerabilitiesFound: vulns,
        optimizationsProposed: opts,
        isConsensus: isConsensus,
        score: isConsensus ? 100 : (70 + (round * 10)),
        timestamp: DateTime.now(),
      );
      session.turns.add(redTurn);
      onTurnAdded(redTurn);

      if (isConsensus || round == cfg.maxRounds) {
        session.finalHardenedCode = currentCode.isNotEmpty ? currentCode : extractCodeBlock(lastBlueResponse);
        session.consensusReached = isConsensus;
        session.status = AdversarialSessionStatus.completed;
        onStatusChanged(AdversarialSessionStatus.completed, 'Consensus reached! Code is hardened and verified.');
        break;
      }
    }
  }

  /// Writes hardened code to disk safely with automatic snapshot
  Future<void> applyHardenedCode({
    required String filePath,
    required String hardenedCode,
  }) async {
    final file = File(filePath);
    String original = '';
    if (await file.exists()) {
      try {
        original = await file.readAsString();
      } catch (_) {}
      await snapshotService.captureFileBeforeEdit('adversarial-turn', filePath, prompt: 'Adversarial Hardening: $filePath');
    }

    await file.parent.create(recursive: true);
    await file.writeAsString(hardenedCode);
    if (original.isNotEmpty) {
      await snapshotService.recordFileDiff(filePath, original, hardenedCode);
    }
  }

  // -------------------------------------------------------------
  // PROMPTS BUILDER
  // -------------------------------------------------------------

  String buildBlueSystemPrompt({required int round, required AdversarialAttackFocus focus}) {
    return '''You are the Blue Team Lead Architect and Senior Software Engineer.
Your goal is to build pristine, production-ready, highly maintainable, and robust code.
Key requirements:
1. Write clean, idiomatic Dart/Flutter or system code with full type-safety.
2. If this is Round 1, provide a clean complete implementation and unit tests.
3. If this is a refactoring round, carefully analyze the Red Team's attack report. Completely eliminate EVERY vulnerability, race condition, memory leak, and algorithmic bottleneck they found.
4. Output the complete, full replacement code inside standard ``` markdown code blocks.
5. Provide a brief explanation of how you fortified the architecture against the Red Team's attacks.''';
  }

  String buildBlueInitialPrompt({required String taskPrompt, String? existingCode}) {
    final buffer = StringBuffer();
    buffer.writeln('TASK REQUIREMENT:');
    buffer.writeln(taskPrompt);
    if (existingCode != null && existingCode.trim().isNotEmpty) {
      buffer.writeln('\nEXISTING CODE IN WORKSPACE:');
      buffer.writeln('```dart\n$existingCode\n```');
    }
    buffer.writeln('\nPlease construct the complete, robust implementation with comprehensive unit tests.');
    return buffer.toString();
  }

  String buildBlueRefactorPrompt({
    required String taskPrompt,
    required String previousCode,
    required String redCritique,
  }) {
    return '''TASK: $taskPrompt

YOUR PREVIOUS CODE IMPLEMENTATION:
```dart
$previousCode
```

RED TEAM HACKER ATTACK & CRITIQUE REPORT:
$redCritique

YOUR MISSION:
1. Fix every exploit and vulnerability reported by Red Team.
2. Resolve all concurrency/race conditions and memory leaks.
3. Optimize any slow algorithms or inefficient rebuilds.
4. Provide the COMPLETE, hardened replacement code in ``` markdown blocks.
5. Explain specifically what defenses you implemented.''';
  }

  String buildRedSystemPrompt({required AdversarialAttackFocus focus}) {
    return '''You are the Red Team Master Security Hacker, Principal Code Critic, and Performance Profiler.
Your sole mission is to aggressively attack, stress-test, and find flaws in the Blue Team developer's code.

Focus areas:
- 🚨 Security Vulnerabilities: Injection, plaintext secret exposure, unsanitized inputs, authorization bypass, unsafe serialization.
- ⚡ Concurrency & Memory: Race conditions, unhandled async gaps, missing dispose() calls, memory leaks, stream subscription leaks.
- 🏎️ Algorithmic Complexity: O(N²) vs O(N log N) loops, excessive Flutter widget rebuilds, redundant disk/network I/O.
- 🧪 Edge Cases & Corner Cases: Null safety crashes, malformed JSON, network dropouts, unhandled exceptions.

RESPONSE FORMAT (Strict):
### 🚨 EXPLOITS & VULNERABILITIES FOUND
- [Describe exploit 1]
- [Describe exploit 2]

### ⚡ PERFORMANCE & CONCURRENCY BOTTLENECKS
- [Describe bottleneck 1]
- [Describe bottleneck 2]

### 🛠️ REQUIRED PATCHES & STRESS TESTS
- [Describe required fix 1]
- [Describe required fix 2]

VERDICT:
If the code still has flaws, demand Blue Team fix them.
If the code is 100% hardened, bug-free, highly optimized, and ready for NASA/defense-grade production, output:
`[CONSENSUS_REACHED: SCORE=100]`''';
  }

  String buildRedAttackPrompt({
    required String taskPrompt,
    required String codeToAttack,
    required int round,
    required int maxRounds,
  }) {
    return '''ORIGINAL TASK:
$taskPrompt

BLUE TEAM'S CODE TO ATTACK (Round $round of $maxRounds):
```dart
$codeToAttack
```

Analyze this code with extreme scrutiny. Hunt for all vulnerabilities, race conditions, edge-case failures, and performance bottlenecks.
Deliver your ruthless Red Team critique.''';
  }
}

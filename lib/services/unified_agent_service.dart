import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/llm_provider.dart';
import '../models/tool_call_log.dart';
import 'rag_service.dart';
import 'snapshot_service.dart';
import 'terminal_service.dart';
import 'workspace_service.dart';

class UnifiedAgentService {
  final WorkspaceService workspaceService;
  final TerminalService terminalService;
  final RagService ragService;
  final SnapshotService snapshotService;

  UnifiedAgentService({
    required this.workspaceService,
    required this.terminalService,
    required this.ragService,
    required this.snapshotService,
  });

  // Tools schema for OpenAI/Groq/OpenRouter
  List<Map<String, dynamic>> _buildOpenAiTools() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'read_file',
          'description': 'Read the contents of a file in the workspace with optional start_line and end_line.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative file path to read'},
              'start_line': {'type': 'integer', 'description': 'Optional 1-indexed start line'},
              'end_line': {'type': 'integer', 'description': 'Optional 1-indexed end line'},
            },
            'required': ['path'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'write_file',
          'description': 'Create or overwrite a file in the workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative file path'},
              'content': {'type': 'string', 'description': 'Full text content to write'},
            },
            'required': ['path', 'content'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'edit_file',
          'description': 'Replace an exact snippet of text in a file with new content.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative file path'},
              'target_content': {'type': 'string', 'description': 'Exact substring to replace'},
              'replacement_content': {'type': 'string', 'description': 'New substring to insert'},
            },
            'required': ['path', 'target_content', 'replacement_content'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'move_file',
          'description': 'Move or rename a file or folder in the workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'source_path': {'type': 'string', 'description': 'Source path'},
              'destination_path': {'type': 'string', 'description': 'Destination path'},
            },
            'required': ['source_path', 'destination_path'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'delete_file',
          'description': 'Delete a file or folder in the workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Path to delete'},
            },
            'required': ['path'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'list_directory',
          'description': 'List contents of a directory in the workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Directory path to list'},
            },
            'required': ['path'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'execute_terminal_command',
          'description': 'Execute a shell command inside the workspace directory.',
          'parameters': {
            'type': 'object',
            'properties': {
              'command': {'type': 'string', 'description': 'Shell command to run'},
            },
            'required': ['command'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'search_codebase',
          'description': 'Perform hybrid semantic and keyword RAG search across the indexed workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {'type': 'string', 'description': 'Search query to find in codebase'},
            },
            'required': ['query'],
          }
        }
      },
    ];
  }

  // Anthropic Claude tools schema
  List<Map<String, dynamic>> _buildAnthropicTools() {
    return _buildOpenAiTools().map((t) {
      final fn = t['function'] as Map<String, dynamic>;
      return {
        'name': fn['name'],
        'description': fn['description'],
        'input_schema': fn['parameters'],
      };
    }).toList();
  }

  // Gemini tools schema
  List<Map<String, dynamic>> _buildGeminiTools() {
    return [
      {
        'function_declarations': _buildOpenAiTools().map((t) {
          final fn = t['function'] as Map<String, dynamic>;
          return {
            'name': fn['name'],
            'description': fn['description'],
            'parameters': fn['parameters'],
          };
        }).toList(),
      }
    ];
  }

  String _buildSystemPrompt() {
    final root = workspaceService.rootPath ?? 'No directory selected yet';
    return '''
You are Flutter-X-Agent, an elite autonomous AI Software Engineer with direct programmatic access to this workspace.
Current Workspace Directory: $root

MISSION & CORE BEHAVIOR:
- YOU ARE AN AUTONOMOUS AGENT, NOT A PASSIVE CHATBOT.
- NEVER give step-by-step tutorials or tell the user to manually create/edit files or run terminal commands.
- YOU MUST EXECUTE ALL ACTIONS DIRECTLY using your provided tools:
  • `write_file`: Create or overwrite files in the workspace (automatically creates any parent directories).
  • `edit_file`: Replace specific snippets inside existing files with target_content and replacement_content.
  • `execute_terminal_command`: Run shell commands directly (e.g., `flutter pub get`, `flutter test`, `flutter analyze`).
  • `read_file`, `list_directory`, `search_codebase`: Inspect existing code before writing or editing.
  • `delete_file`, `move_file`: Manage workspace files.

CRITICAL DIRECTIVES:
1. When asked to build, create, or modify screens/features (e.g. splash screen, onboarding, login, signup, home, state management, routes):
   DO NOT output conversational tutorials. IMMEDIATELY call `write_file` for each file (e.g. `lib/main.dart`, `lib/onboarding.dart`, `lib/screens.dart`, `pubspec.yaml`, `android/...`).
2. When packages or assets need to be configured:
   Update `pubspec.yaml` using `write_file` or `edit_file`, and run `flutter pub get` via `execute_terminal_command`.
3. If building an interactive web preview or HTML component, output clean HTML inside ```html ``` code blocks.
4. Always write complete, production-ready, compile-clean code with all required imports.
5. EXECUTE IMMEDIATELY. Do not ask for user confirmation to write files—execute the tools now!
''';
  }

  Future<void> runAgentTurn({
    required LlmProviderType provider,
    required String apiKey,
    required String modelName,
    required double temperature,
    required List<ChatMessage> conversationHistory,
    required String userPrompt,
    required Function(ToolCallLog) onToolStarted,
    required Function(ToolCallLog) onToolCompleted,
    required Function(String chunk) onContentUpdated,
    required Function(List<String> ragSources) onRagSourcesFound,
  }) async {
    final turnId = const Uuid().v4();

    // RAG Context Enrichment
    String promptWithRag = userPrompt;
    final ragSources = <String>[];

    try {
      final ragResults = await ragService.search(userPrompt, topK: 3, geminiApiKey: apiKey);
      if (ragResults.isNotEmpty) {
        final ragContext = ragService.formatRagContext(ragResults);
        promptWithRag = '$ragContext\nUser Request: $userPrompt';
        ragSources.addAll(ragResults.map((r) => '${r.chunk.relativePath} (L${r.chunk.startLine}-${r.chunk.endLine})'));
        onRagSourcesFound(ragSources);
      }
    } catch (_) {}

    switch (provider) {
      case LlmProviderType.gemini:
        await _runGeminiTurn(
          apiKey: apiKey,
          modelName: modelName,
          temperature: temperature,
          conversationHistory: conversationHistory,
          promptWithRag: promptWithRag,
          turnId: turnId,
          onToolStarted: onToolStarted,
          onToolCompleted: onToolCompleted,
          onContentUpdated: onContentUpdated,
        );
        break;

      case LlmProviderType.anthropic:
        await _runAnthropicTurn(
          apiKey: apiKey,
          modelName: modelName,
          temperature: temperature,
          conversationHistory: conversationHistory,
          promptWithRag: promptWithRag,
          turnId: turnId,
          onToolStarted: onToolStarted,
          onToolCompleted: onToolCompleted,
          onContentUpdated: onContentUpdated,
        );
        break;

      case LlmProviderType.groq:
      case LlmProviderType.openrouter:
      case LlmProviderType.ollama:
        await _runOpenAiCompatibleTurn(
          provider: provider,
          apiKey: apiKey,
          modelName: modelName,
          temperature: temperature,
          conversationHistory: conversationHistory,
          promptWithRag: promptWithRag,
          turnId: turnId,
          onToolStarted: onToolStarted,
          onToolCompleted: onToolCompleted,
          onContentUpdated: onContentUpdated,
        );
        break;
    }
  }

  // --- 1. GEMINI TURN ---
  Future<void> _runGeminiTurn({
    required String apiKey,
    required String modelName,
    required double temperature,
    required List<ChatMessage> conversationHistory,
    required String promptWithRag,
    required String turnId,
    required Function(ToolCallLog) onToolStarted,
    required Function(ToolCallLog) onToolCompleted,
    required Function(String chunk) onContentUpdated,
  }) async {
    final cleanModel = modelName.startsWith('models/') ? modelName.substring(7) : modelName;
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent?key=$apiKey');

    final contents = <Map<String, dynamic>>[];
    for (final msg in conversationHistory) {
      if (msg.role == MessageRole.user) {
        contents.add({'role': 'user', 'parts': [{'text': msg.content}]});
      } else if (msg.role == MessageRole.assistant && msg.content.trim().isNotEmpty) {
        contents.add({'role': 'model', 'parts': [{'text': msg.content}]});
      }
    }
    contents.add({'role': 'user', 'parts': [{'text': promptWithRag}]});

    final tools = _buildGeminiTools();
    final systemPrompt = _buildSystemPrompt();
    final finalResponseBuffer = StringBuffer();
    int loopCount = 0;
    int executedToolsCount = 0;

    while (loopCount < 15) {
      loopCount++;
      final payload = {
        'system_instruction': {'parts': [{'text': systemPrompt}]},
        'contents': contents,
        'tools': tools,
        'generationConfig': {'temperature': temperature},
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(responseBody['error']?['message'] ?? 'Gemini Error: ${response.statusCode}');
      }

      final candidates = responseBody['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) break;

      final candidateContent = (candidates[0] as Map<String, dynamic>)['content'] as Map<String, dynamic>? ?? {};
      final parts = (candidateContent['parts'] as List<dynamic>?) ?? [];
      contents.add(Map<String, dynamic>.from(candidateContent));

      final functionCalls = <Map<String, dynamic>>[];
      for (final part in parts) {
        if (part is Map<String, dynamic>) {
          if (part.containsKey('text') && part['text'] != null) {
            final text = part['text'].toString();
            finalResponseBuffer.write(text);
            onContentUpdated(finalResponseBuffer.toString());
          }
          if (part.containsKey('functionCall')) {
            functionCalls.add(Map<String, dynamic>.from(part['functionCall'] as Map));
          }
        }
      }

      if (functionCalls.isEmpty) break;

      final functionResponseParts = <Map<String, dynamic>>[];
      for (final call in functionCalls) {
        executedToolsCount++;
        final name = call['name'] as String? ?? '';
        final args = (call['args'] as Map<String, dynamic>?) ?? {};

        final toolLog = ToolCallLog(
          id: const Uuid().v4(),
          toolName: name,
          arguments: args,
          status: ToolStatus.running,
        );
        onToolStarted(toolLog);

        dynamic toolResult;
        try {
          toolResult = await _executeTool(name, args, turnId);
          toolLog.status = ToolStatus.success;
          toolLog.output = toolResult.toString();
        } catch (err) {
          toolLog.status = ToolStatus.failed;
          toolLog.output = 'Error executing $name: $err';
          toolResult = {'error': err.toString()};
        }
        onToolCompleted(toolLog);

        functionResponseParts.add({
          'functionResponse': {
            'name': name,
            'response': toolResult is Map<String, dynamic> ? toolResult : {'result': toolResult.toString()},
          }
        });
      }

      contents.add({'role': 'user', 'parts': functionResponseParts});
    }

    if (executedToolsCount == 0) {
      await _autoApplyMarkdownActions(
        responseText: finalResponseBuffer.toString(),
        turnId: turnId,
        onToolStarted: onToolStarted,
        onToolCompleted: onToolCompleted,
        onContentUpdated: (updated) {
          finalResponseBuffer.clear();
          finalResponseBuffer.write(updated);
          onContentUpdated(updated);
        },
      );
    }

    if (finalResponseBuffer.isEmpty) onContentUpdated('Task completed.');
  }

  // --- 2. ANTHROPIC CLAUDE TURN ---
  Future<void> _runAnthropicTurn({
    required String apiKey,
    required String modelName,
    required double temperature,
    required List<ChatMessage> conversationHistory,
    required String promptWithRag,
    required String turnId,
    required Function(ToolCallLog) onToolStarted,
    required Function(ToolCallLog) onToolCompleted,
    required Function(String chunk) onContentUpdated,
  }) async {
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final messages = <Map<String, dynamic>>[];
    for (final msg in conversationHistory) {
      if (msg.role == MessageRole.user) {
        messages.add({'role': 'user', 'content': msg.content});
      } else if (msg.role == MessageRole.assistant && msg.content.trim().isNotEmpty) {
        messages.add({'role': 'assistant', 'content': msg.content});
      }
    }
    messages.add({'role': 'user', 'content': promptWithRag});

    final tools = _buildAnthropicTools();
    final systemPrompt = _buildSystemPrompt();
    final finalResponseBuffer = StringBuffer();
    int loopCount = 0;
    int executedToolsCount = 0;

    while (loopCount < 15) {
      loopCount++;
      final payload = {
        'model': modelName,
        'max_tokens': 4096,
        'temperature': temperature,
        'system': systemPrompt,
        'messages': messages,
        'tools': tools,
      };

      final response = await http.post(
        url,
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(responseBody['error']?['message'] ?? 'Anthropic Error: ${response.statusCode}');
      }

      final contentList = responseBody['content'] as List<dynamic>? ?? [];
      messages.add({'role': 'assistant', 'content': contentList});

      final toolUseCalls = <Map<String, dynamic>>[];
      for (final item in contentList) {
        if (item is Map<String, dynamic>) {
          if (item['type'] == 'text' && item['text'] != null) {
            final text = item['text'].toString();
            finalResponseBuffer.write(text);
            onContentUpdated(finalResponseBuffer.toString());
          }
          if (item['type'] == 'tool_use') {
            toolUseCalls.add(item);
          }
        }
      }

      if (toolUseCalls.isEmpty) break;

      final toolResultContents = <Map<String, dynamic>>[];
      for (final call in toolUseCalls) {
        executedToolsCount++;
        final callId = call['id'] as String;
        final name = call['name'] as String;
        final input = (call['input'] as Map<String, dynamic>?) ?? {};

        final toolLog = ToolCallLog(
          id: const Uuid().v4(),
          toolName: name,
          arguments: input,
          status: ToolStatus.running,
        );
        onToolStarted(toolLog);

        dynamic toolResult;
        try {
          toolResult = await _executeTool(name, input, turnId);
          toolLog.status = ToolStatus.success;
          toolLog.output = toolResult.toString();
        } catch (err) {
          toolLog.status = ToolStatus.failed;
          toolLog.output = 'Error executing $name: $err';
          toolResult = {'error': err.toString()};
        }
        onToolCompleted(toolLog);

        toolResultContents.add({
          'type': 'tool_result',
          'tool_use_id': callId,
          'content': toolResult is Map ? jsonEncode(toolResult) : toolResult.toString(),
        });
      }

      messages.add({'role': 'user', 'content': toolResultContents});
    }

    if (executedToolsCount == 0) {
      await _autoApplyMarkdownActions(
        responseText: finalResponseBuffer.toString(),
        turnId: turnId,
        onToolStarted: onToolStarted,
        onToolCompleted: onToolCompleted,
        onContentUpdated: (updated) {
          finalResponseBuffer.clear();
          finalResponseBuffer.write(updated);
          onContentUpdated(updated);
        },
      );
    }

    if (finalResponseBuffer.isEmpty) onContentUpdated('Task completed.');
  }

  // --- 3. OPENAI-COMPATIBLE TURN (Groq, OpenRouter, Ollama) ---
  Future<void> _runOpenAiCompatibleTurn({
    required LlmProviderType provider,
    required String apiKey,
    required String modelName,
    required double temperature,
    required List<ChatMessage> conversationHistory,
    required String promptWithRag,
    required String turnId,
    required Function(ToolCallLog) onToolStarted,
    required Function(ToolCallLog) onToolCompleted,
    required Function(String chunk) onContentUpdated,
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

    final messages = <Map<String, dynamic>>[];
    messages.add({'role': 'system', 'content': _buildSystemPrompt()});

    for (final msg in conversationHistory) {
      if (msg.role == MessageRole.user) {
        messages.add({'role': 'user', 'content': msg.content});
      } else if (msg.role == MessageRole.assistant && msg.content.trim().isNotEmpty) {
        messages.add({'role': 'assistant', 'content': msg.content});
      }
    }
    messages.add({'role': 'user', 'content': promptWithRag});

    String effectiveModel = modelName.trim();
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
    }

    final tools = _buildOpenAiTools();
    final finalResponseBuffer = StringBuffer();
    int loopCount = 0;
    int executedToolsCount = 0;

    while (loopCount < 15) {
      loopCount++;
      final payload = {
        'model': effectiveModel,
        'temperature': temperature,
        'messages': messages,
        'tools': tools,
        'tool_choice': 'auto',
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        final errMsg = responseBody['error']?['message'] ?? responseBody['error'] ?? 'API Error: ${response.statusCode}';
        if (provider == LlmProviderType.ollama && errMsg.toString().contains('not found')) {
          throw Exception(
            'Local Ollama model "$effectiveModel" is not downloaded yet.\n'
            'Please run in terminal: `ollama pull $effectiveModel`\n'
            'Or select an already installed model from Settings (⚙️).'
          );
        }
        throw Exception(errMsg.toString());
      }

      final choices = responseBody['choices'] as List<dynamic>? ?? [];
      if (choices.isEmpty) break;

      final messageObj = choices[0]['message'] as Map<String, dynamic>? ?? {};
      messages.add(messageObj);

      final contentText = messageObj['content'] as String?;
      if (contentText != null && contentText.isNotEmpty) {
        finalResponseBuffer.write(contentText);
        onContentUpdated(finalResponseBuffer.toString());
      }

      final toolCalls = messageObj['tool_calls'] as List<dynamic>? ?? [];
      if (toolCalls.isEmpty) break;

      for (final call in toolCalls) {
        executedToolsCount++;
        final callId = call['id'] as String? ?? const Uuid().v4();
        final fn = call['function'] as Map<String, dynamic>;
        final name = fn['name'] as String;
        Map<String, dynamic> args = {};
        try {
          args = jsonDecode(fn['arguments'] as String);
        } catch (_) {}

        final toolLog = ToolCallLog(
          id: const Uuid().v4(),
          toolName: name,
          arguments: args,
          status: ToolStatus.running,
        );
        onToolStarted(toolLog);

        dynamic toolResult;
        try {
          toolResult = await _executeTool(name, args, turnId);
          toolLog.status = ToolStatus.success;
          toolLog.output = toolResult.toString();
        } catch (err) {
          toolLog.status = ToolStatus.failed;
          toolLog.output = 'Error executing $name: $err';
          toolResult = {'error': err.toString()};
        }
        onToolCompleted(toolLog);

        messages.add({
          'role': 'tool',
          'tool_call_id': callId,
          'name': name,
          'content': toolResult is Map ? jsonEncode(toolResult) : toolResult.toString(),
        });
      }
    }

    if (executedToolsCount == 0) {
      await _autoApplyMarkdownActions(
        responseText: finalResponseBuffer.toString(),
        turnId: turnId,
        onToolStarted: onToolStarted,
        onToolCompleted: onToolCompleted,
        onContentUpdated: (updated) {
          finalResponseBuffer.clear();
          finalResponseBuffer.write(updated);
          onContentUpdated(updated);
        },
      );
    }

    if (finalResponseBuffer.isEmpty) onContentUpdated('Task completed.');
  }

  /// Automatically parses and executes files and commands emitted in markdown text responses
  Future<void> _autoApplyMarkdownActions({
    required String responseText,
    required String turnId,
    required Function(ToolCallLog) onToolStarted,
    required Function(ToolCallLog) onToolCompleted,
    required Function(String updatedContent) onContentUpdated,
  }) async {
    if (responseText.trim().isEmpty) return;

    final createdFiles = <String>[];
    final executedCommands = <String>[];

    // 1. Check for JSON tool calls formatted in text
    final jsonToolRegex = RegExp(
      r'\{\s*"name"\s*:\s*"(write_file|edit_file|execute_terminal_command)"\s*,\s*"(?:parameters|arguments)"\s*:\s*(\{[\s\S]*?\})\s*\}',
      caseSensitive: false,
    );
    for (final match in jsonToolRegex.allMatches(responseText)) {
      final toolName = match.group(1)!;
      final rawArgs = match.group(2)!;
      try {
        final args = jsonDecode(rawArgs) as Map<String, dynamic>;
        final toolLog = ToolCallLog(
          id: const Uuid().v4(),
          toolName: toolName,
          arguments: args,
          status: ToolStatus.running,
        );
        onToolStarted(toolLog);
        try {
          final res = await _executeTool(toolName, args, turnId);
          toolLog.status = ToolStatus.success;
          toolLog.output = res.toString();
          if (toolName == 'write_file' || toolName == 'edit_file') {
            createdFiles.add(args['path']?.toString() ?? 'file');
          } else if (toolName == 'execute_terminal_command') {
            executedCommands.add(args['command']?.toString() ?? 'command');
          }
        } catch (err) {
          toolLog.status = ToolStatus.failed;
          toolLog.output = 'Error executing $toolName: $err';
        }
        onToolCompleted(toolLog);
      } catch (_) {}
    }

    // 2. Extract Markdown code blocks with associated file names
    final extractedFiles = extractMarkdownFileBlocks(responseText);
    for (final entry in extractedFiles.entries) {
      final path = entry.key;
      final content = entry.value;

      if (createdFiles.contains(path)) continue;

      final toolLog = ToolCallLog(
        id: const Uuid().v4(),
        toolName: 'write_file',
        arguments: {'path': path, 'content': content},
        status: ToolStatus.running,
      );
      onToolStarted(toolLog);

      try {
        final res = await _executeTool('write_file', {'path': path, 'content': content}, turnId);
        toolLog.status = ToolStatus.success;
        toolLog.output = 'Auto-written file: $path ($res)';
        createdFiles.add(path);
      } catch (err) {
        toolLog.status = ToolStatus.failed;
        toolLog.output = 'Error auto-writing $path: $err';
      }
      onToolCompleted(toolLog);
    }

    // 3. Extract safe setup/build commands mentioned to run
    final extractedCmds = extractMarkdownCommands(responseText);
    for (final cmd in extractedCmds) {
      if (executedCommands.contains(cmd)) continue;
      final toolLog = ToolCallLog(
        id: const Uuid().v4(),
        toolName: 'execute_terminal_command',
        arguments: {'command': cmd},
        status: ToolStatus.running,
      );
      onToolStarted(toolLog);

      try {
        final res = await _executeTool('execute_terminal_command', {'command': cmd}, turnId);
        toolLog.status = ToolStatus.success;
        toolLog.output = res.toString();
        executedCommands.add(cmd);
      } catch (err) {
        toolLog.status = ToolStatus.failed;
        toolLog.output = 'Error executing $cmd: $err';
      }
      onToolCompleted(toolLog);
    }

    if (createdFiles.isNotEmpty || executedCommands.isNotEmpty) {
      final summaryBuffer = StringBuffer(responseText);
      summaryBuffer.writeln('\n\n---');
      summaryBuffer.writeln('⚡ **Autonomous Actions Auto-Executed:**');
      for (final f in createdFiles) {
        summaryBuffer.writeln('• 📄 Auto-generated workspace file: `$f`');
      }
      for (final c in executedCommands) {
        summaryBuffer.writeln('• 💻 Executed terminal command: `$c`');
      }
      onContentUpdated(summaryBuffer.toString());
    }
  }

  /// Extracts file names and contents from markdown text
  Map<String, String> extractMarkdownFileBlocks(String text) {
    final files = <String, String>{};
    final codeBlockRegex = RegExp(r'```([a-zA-Z0-9_\-]*)\n([\s\S]*?)```');
    final matches = codeBlockRegex.allMatches(text).toList();

    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final lang = match.group(1)?.trim().toLowerCase() ?? '';
      final code = match.group(2) ?? '';

      if (lang == 'sh' || lang == 'bash' || lang == 'shell' || lang == 'zsh') {
        continue;
      }

      String? detectedPath;
      String? dirHint;

      // 1. Check first 3 lines of code for path comments
      final codeLines = code.split('\n').take(3);
      for (final line in codeLines) {
        final commentMatch = RegExp(
          r'^(?:\/\/|#|<!--|\/\*)\s*(?:file:\s*)?([a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+)(?:\s*-->|\s*\*\/)?',
          caseSensitive: false,
        ).firstMatch(line.trim());
        if (commentMatch != null) {
          detectedPath = commentMatch.group(1);
          break;
        }
      }

      // 2. Look back in text before this code block (bounded by previous code block end)
      if (detectedPath == null) {
        final prevEnd = i > 0 ? matches[i - 1].end : 0;
        final lookbackStart = math.max(prevEnd, match.start - 400);
        final lookback = text.substring(lookbackStart, match.start);

        final dirFileMatch1 = RegExp(
          r'(?:create|add|place|put)(?: a)?\s*[`*"]?([a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+)[`*"]?\s*(?:file)?\s*in\s*(?:the\s*)?(?:directory\s*)?[`*"]?([a-zA-Z0-9_\-./]+)[`*"]?',
          caseSensitive: false,
        ).allMatches(lookback).lastOrNull;

        final dirFileMatch2 = RegExp(
          r'in\s*(?:the\s*)?(?:directory\s*)?[`*"]?([a-zA-Z0-9_\-./]+)[`*"]?,?\s*(?:create|add|place)\s*(?:a\s*)?(?:new\s*)?[`*"]?([a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+)[`*"]?',
          caseSensitive: false,
        ).allMatches(lookback).lastOrNull;

        if (dirFileMatch1 != null) {
          detectedPath = dirFileMatch1.group(1);
          dirHint = dirFileMatch1.group(2);
        } else if (dirFileMatch2 != null) {
          dirHint = dirFileMatch2.group(1);
          detectedPath = dirFileMatch2.group(2);
        } else {
          final generalMatch = RegExp(
            r'(?:create|update|add|edit|modify|in|to|file|filename|new file)\s+(?:a\s+)?(?:new\s+)?(?:file\s+)?(?:it\s+to\s+)?(?:your\s+)?[`*"]?([a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+)[`*"]?',
            caseSensitive: false,
          ).allMatches(lookback).lastOrNull;

          if (generalMatch != null) {
            detectedPath = generalMatch.group(1);
          } else {
            final boldOrHeader = RegExp(
              r'(?:###|##|#|\*\*|`)\s*(?:Step \d+:?\s*)?(?:[a-zA-Z0-9_\- ]+)?([a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+)(?:\*\*|`)?:?',
              caseSensitive: false,
            ).allMatches(lookback).lastOrNull;
            if (boldOrHeader != null) {
              detectedPath = boldOrHeader.group(1);
            }
          }
        }
      }

      if (detectedPath != null) {
        final resolved = normalizeFilePath(detectedPath, directoryHint: dirHint);
        if (resolved != null && code.trim().isNotEmpty) {
          files[resolved] = code.trim();
        }
      }
    }

    return files;
  }

  /// Extracts runnable terminal commands from markdown text
  List<String> extractMarkdownCommands(String text) {
    final commands = <String>[];
    final codeBlockRegex = RegExp(r'```([a-zA-Z0-9_\-]*)\s*\r?\n([\s\S]*?)```');
    final matches = codeBlockRegex.allMatches(text);

    for (final match in matches) {
      final lang = match.group(1)?.trim().toLowerCase() ?? '';
      final content = match.group(2) ?? '';

      final isShellBlock = lang == 'sh' ||
          lang == 'bash' ||
          lang == 'shell' ||
          lang == 'zsh' ||
          lang == 'terminal' ||
          lang == 'cmd' ||
          lang == '';

      final lines = content.split('\n');
      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) continue;

        if (line.startsWith('flutter ') ||
            line.startsWith('dart ') ||
            line.startsWith('npm ') ||
            line.startsWith('pod ')) {
          if (!commands.contains(line)) {
            commands.add(line);
          }
        }
      }
    }
    return commands;
  }

  /// Normalizes a raw file path (adding directory prefix if needed)
  String? normalizeFilePath(String rawPath, {String? directoryHint}) {
    if (rawPath.contains('http:') ||
        rawPath.contains('https:') ||
        rawPath.contains('://') ||
        rawPath.contains('package:') ||
        rawPath.contains('www.')) {
      return null;
    }

    var clean = rawPath
        .replaceAll('`', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('*', '')
        .replaceAll(':', '')
        .trim();

    if (clean.isEmpty) {
      return null;
    }

    if (directoryHint != null && directoryHint.isNotEmpty && !clean.contains('/')) {
      var cleanDir = directoryHint
          .replaceAll('`', '')
          .replaceAll('"', '')
          .replaceAll("'", '')
          .trim();
      if (cleanDir.endsWith('/')) cleanDir = cleanDir.substring(0, cleanDir.length - 1);
      clean = '$cleanDir/$clean';
    }

    if (clean.startsWith('/')) {
      clean = clean.substring(1);
    }

    final extMatch = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(clean);
    if (extMatch == null) return null;
    final ext = extMatch.group(1)!.toLowerCase();

    final validExts = {
      'dart', 'yaml', 'yml', 'xml', 'json', 'js', 'ts', 'html', 'css',
      'py', 'sh', 'kt', 'swift', 'java', 'cpp', 'c', 'h', 'sql', 'md',
      'txt', 'gradle', 'properties', 'env', 'plist',
    };
    if (!validExts.contains(ext)) return null;

    if (ext == 'dart' && !clean.contains('/')) {
      clean = 'lib/$clean';
    }

    return clean;
  }

  // --- DYNAMIC MODEL FETCHER API ---
  Future<List<LlmModelInfo>> fetchWorkingModels(LlmProviderType provider, String apiKey) async {
    try {
      if (provider == LlmProviderType.groq) {
        final res = await http.get(
          Uri.parse('https://api.groq.com/openai/v1/models'),
          headers: {'Authorization': 'Bearer $apiKey'},
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final list = (data['data'] as List<dynamic>?) ?? [];
          return list.map((m) {
            final id = m['id'].toString();
            final isFree = true; // All groq free tier models
            return LlmModelInfo(
              id: id,
              displayName: '$id (Groq)',
              provider: LlmProviderType.groq,
              isFree: isFree,
            );
          }).toList();
        }
      } else if (provider == LlmProviderType.gemini) {
        final res = await http.get(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey'),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final list = (data['models'] as List<dynamic>?) ?? [];
          return list
              .where((m) => (m['supportedGenerationMethods'] as List<dynamic>? ?? []).contains('generateContent'))
              .map((m) {
            final name = m['name'].toString().replaceFirst('models/', '');
            final isFree = name.contains('flash');
            return LlmModelInfo(
              id: name,
              displayName: name,
              provider: LlmProviderType.gemini,
              isFree: isFree,
            );
          }).toList();
        }
      } else if (provider == LlmProviderType.openrouter) {
        final res = await http.get(
          Uri.parse('https://openrouter.ai/api/v1/models'),
          headers: {'Authorization': 'Bearer $apiKey'},
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final list = (data['data'] as List<dynamic>?) ?? [];
          return list.map((m) {
            final id = m['id'].toString();
            final isFree = id.contains(':free');
            return LlmModelInfo(
              id: id,
              displayName: '$id (OpenRouter)',
              provider: LlmProviderType.openrouter,
              isFree: isFree,
            );
          }).toList();
        }
      } else if (provider == LlmProviderType.ollama) {
        final host = apiKey.isNotEmpty && apiKey.startsWith('http') ? apiKey : 'http://localhost:11434';
        final res = await http.get(Uri.parse('$host/api/tags'));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final list = (data['models'] as List<dynamic>?) ?? [];
          return list.map((m) {
            final name = m['name'].toString();
            return LlmModelInfo(
              id: name,
              displayName: '$name (Local)',
              provider: LlmProviderType.ollama,
              isFree: true,
            );
          }).toList();
        }
      }
    } catch (_) {}
    return LlmProviderUtils.defaultModels.where((m) => m.provider == provider).toList();
  }

  Future<dynamic> _executeTool(String name, Map<String, dynamic> args, String turnId) async {
    switch (name) {
      case 'read_file':
        final path = args['path'] as String;
        final start = args['start_line'] as int?;
        final end = args['end_line'] as int?;
        return await workspaceService.readFile(path, startLine: start, endLine: end);

      case 'write_file':
        final path = args['path'] as String;
        final content = args['content'] as String;
        // Snapshot original state before write
        await snapshotService.captureFileBeforeEdit(turnId, path);
        String oldContent = '';
        try {
          oldContent = await workspaceService.readFile(path);
        } catch (_) {}
        final res = await workspaceService.writeFile(path, content);
        await snapshotService.recordFileDiff(path, oldContent, content);
        return res;

      case 'edit_file':
        final path = args['path'] as String;
        final target = args['target_content'] as String;
        final replacement = args['replacement_content'] as String;
        // Snapshot original state before edit
        await snapshotService.captureFileBeforeEdit(turnId, path);
        final oldContent = await workspaceService.readFile(path);
        final res = await workspaceService.editFile(path, target, replacement);
        final newContent = await workspaceService.readFile(path);
        await snapshotService.recordFileDiff(path, oldContent, newContent);
        return res;

      case 'move_file':
        final src = args['source_path'] as String;
        final dest = args['destination_path'] as String;
        await snapshotService.captureFileBeforeEdit(turnId, src);
        return await workspaceService.moveFile(src, dest);

      case 'delete_file':
        final path = args['path'] as String;
        await snapshotService.captureFileBeforeEdit(turnId, path);
        return await workspaceService.deleteFile(path);

      case 'list_directory':
        final path = args['path'] as String? ?? '.';
        final items = await workspaceService.listDirectory(path);
        return {'items': items};

      case 'execute_terminal_command':
        final command = args['command'] as String;
        final workDir = workspaceService.rootPath ?? '.';
        final res = await terminalService.execute(command, workingDirectory: workDir);
        return {
          'command': res.command,
          'stdout': res.stdout,
          'stderr': res.stderr,
          'exitCode': res.exitCode,
          'durationMs': res.duration.inMilliseconds,
        };

      case 'search_codebase':
        final query = args['query'] as String;
        final results = await ragService.search(query, topK: 5);
        return {
          'results': results
              .map((r) => {
                    'file': r.chunk.relativePath,
                    'startLine': r.chunk.startLine,
                    'endLine': r.chunk.endLine,
                    'preview': r.chunk.content,
                    'match': r.matchReason,
                  })
              .toList(),
        };

      default:
        throw Exception('Unknown tool: $name');
    }
  }
}

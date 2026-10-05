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

  http.Client? _activeClient;
  bool _isCancelled = false;

  UnifiedAgentService({
    required this.workspaceService,
    required this.terminalService,
    required this.ragService,
    required this.snapshotService,
  });

  void cancelActiveTurn() {
    _isCancelled = true;
    _activeClient?.close();
    _activeClient = null;
  }

  // Tools schema for OpenAI/Groq/OpenRouter/Ollama
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
          'description': 'Create or overwrite a file in the workspace with new code.',
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
          'description': 'Execute a shell command inside the workspace directory (e.g. flutter pub get, flutter test).',
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
    final root = workspaceService.rootPath ?? 'Current working directory';
    return '''
You are Flutter-X-Agent, an elite autonomous AI Software Engineer with direct programmatic access to this workspace.
Workspace Directory: $root

CRITICAL SAFETY & EXECUTION DIRECTIVES:
1. NEVER output passive tutorials, theoretical text, or tell the user to manually copy/paste code or run commands.
2. YOU MUST ALWAYS IMPLEMENT DIRECTLY:
   - When writing new files or rewriting existing ones, call `write_file` or format file blocks as:
     ### File: path/to/file.dart
     ```dart
     // complete code here
     ```
   - When editing existing code, call `edit_file` with exact target_content and replacement_content.
   - When terminal commands are required (e.g. `flutter pub get`, `flutter test`), call `execute_terminal_command`.
   - When inspecting the codebase, call `search_codebase`, `read_file`, or `list_directory`.
3. NEVER delete whole project folders or essential directories (like `lib`, `android`, `ios`, `test`) unless explicitly commanded to wipe/reset the project.
4. NEVER output raw JSON tool-call syntax in your visible chat response text.
5. Provide complete, compile-clean code with all imports and explain your work cleanly.
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
    Function(String statusStep)? onStatusStepUpdated,
  }) async {
    _isCancelled = false;
    _activeClient = http.Client();
    final turnId = const Uuid().v4();

    // RAG Context Enrichment
    String promptWithRag = userPrompt;
    final ragSources = <String>[];

    try {
      onStatusStepUpdated?.call('🔍 Searching codebase & context...');
      final ragResults = await ragService.search(userPrompt, topK: 3, geminiApiKey: apiKey);
      if (ragResults.isNotEmpty) {
        final ragContext = ragService.formatRagContext(ragResults);
        promptWithRag = '$ragContext\nUser Request: $userPrompt';
        ragSources.addAll(ragResults.map((r) => '${r.chunk.relativePath} (L${r.chunk.startLine}-${r.chunk.endLine})'));
        onRagSourcesFound(ragSources);
      }
    } catch (_) {}

    try {
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
            onStatusStepUpdated: onStatusStepUpdated,
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
            onStatusStepUpdated: onStatusStepUpdated,
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
            onStatusStepUpdated: onStatusStepUpdated,
          );
          break;
      }
    } finally {
      _activeClient?.close();
      _activeClient = null;
    }
  }

  // --- 1. GEMINI TURN (STREAMING SUPPORT) ---
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
    Function(String statusStep)? onStatusStepUpdated,
  }) async {
    final cleanModel = modelName.startsWith('models/') ? modelName.substring(7) : modelName;
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:streamGenerateContent?alt=sse&key=$apiKey');

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

    while (loopCount < 15 && !_isCancelled) {
      loopCount++;
      final payload = {
        'system_instruction': {'parts': [{'text': systemPrompt}]},
        'contents': contents,
        'tools': tools,
        'generationConfig': {'temperature': temperature},
      };

      final request = http.Request('POST', url)
        ..headers.addAll({'Content-Type': 'application/json'})
        ..body = jsonEncode(payload);

      final client = _activeClient ?? http.Client();
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        final errBody = await streamedResponse.stream.bytesToString();
        Map<String, dynamic> errJson = {};
        try {
          errJson = jsonDecode(errBody);
        } catch (_) {}
        throw Exception(errJson['error']?['message'] ?? 'Gemini API Error: ${streamedResponse.statusCode}');
      }

      final functionCalls = <Map<String, dynamic>>[];
      final turnBuffer = StringBuffer();

      await for (final line in streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (_isCancelled) break;
        if (!line.startsWith('data: ')) continue;
        final rawData = line.substring(6).trim();
        if (rawData.isEmpty || rawData == '[DONE]') continue;

        try {
          final data = jsonDecode(rawData) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) continue;

          final contentObj = (candidates[0] as Map<String, dynamic>)['content'] as Map<String, dynamic>? ?? {};
          final parts = (contentObj['parts'] as List<dynamic>?) ?? [];

          for (final part in parts) {
            if (part is Map<String, dynamic>) {
              if (part.containsKey('text') && part['text'] != null) {
                final chunk = part['text'].toString();
                turnBuffer.write(chunk);
                finalResponseBuffer.write(chunk);
                onContentUpdated(finalResponseBuffer.toString());
              }
              if (part.containsKey('functionCall')) {
                functionCalls.add(Map<String, dynamic>.from(part['functionCall'] as Map));
              }
            }
          }
        } catch (_) {}
      }

      if (_isCancelled) {
        finalResponseBuffer.writeln('\n\n🛑 *Task stopped by user.*');
        onContentUpdated(finalResponseBuffer.toString());
        return;
      }

      if (turnBuffer.isNotEmpty) {
        contents.add({
          'role': 'model',
          'parts': [{'text': turnBuffer.toString()}],
        });
      }

      if (functionCalls.isEmpty) break;

      final functionResponseParts = <Map<String, dynamic>>[];
      for (final call in functionCalls) {
        if (_isCancelled) break;
        executedToolsCount++;
        final name = call['name'] as String? ?? '';
        final args = (call['args'] as Map<String, dynamic>?) ?? {};

        final stepDesc = _getStepDescription(name, args);
        final toolLog = ToolCallLog(
          id: const Uuid().v4(),
          toolName: name,
          arguments: args,
          status: ToolStatus.running,
          stepDescription: stepDesc,
        );
        onToolStarted(toolLog);

        dynamic toolResult;
        try {
          final execResult = await _executeTool(name, args, turnId);
          toolResult = execResult['result'];
          toolLog.diffStats = execResult['diffStats'] as String?;
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

    if (executedToolsCount == 0 && !_isCancelled) {
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

  // --- 2. ANTHROPIC CLAUDE TURN (STREAMING SUPPORT) ---
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
    Function(String statusStep)? onStatusStepUpdated,
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

    while (loopCount < 15 && !_isCancelled) {
      loopCount++;
      final payload = {
        'model': modelName,
        'max_tokens': 4096,
        'temperature': temperature,
        'system': systemPrompt,
        'messages': messages,
        'tools': tools,
      };

      final response = await (_activeClient ?? http.Client()).post(
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
        if (_isCancelled) break;
        executedToolsCount++;
        final callId = call['id'] as String;
        final name = call['name'] as String;
        final input = (call['input'] as Map<String, dynamic>?) ?? {};

        final stepDesc = _getStepDescription(name, input);
        final toolLog = ToolCallLog(
          id: const Uuid().v4(),
          toolName: name,
          arguments: input,
          status: ToolStatus.running,
          stepDescription: stepDesc,
        );
        onToolStarted(toolLog);

        dynamic toolResult;
        try {
          final execResult = await _executeTool(name, input, turnId);
          toolResult = execResult['result'];
          toolLog.diffStats = execResult['diffStats'] as String?;
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

    if (executedToolsCount == 0 && !_isCancelled) {
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

  // --- 3. OPENAI-COMPATIBLE TURN (STREAMING SUPPORT: Groq, OpenRouter, Ollama) ---
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
    Function(String statusStep)? onStatusStepUpdated,
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
      final host = apiKey.isNotEmpty && apiKey.startsWith('http') ? apiKey : 'http://localhost:11434';
      url = Uri.parse('$host/v1/chat/completions');
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

    while (loopCount < 15 && !_isCancelled) {
      loopCount++;
      final payload = {
        'model': effectiveModel,
        'temperature': temperature,
        'messages': messages,
        'tools': tools,
        'tool_choice': 'auto',
        'stream': true,
      };

      final request = http.Request('POST', url)
        ..headers.addAll(headers)
        ..body = jsonEncode(payload);

      final client = _activeClient ?? http.Client();
      http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await client.send(request);
      } catch (e) {
        if (_isCancelled) return;
        throw Exception('Connection failed to $url ($e)');
      }

      if (streamedResponse.statusCode != 200) {
        final errText = await streamedResponse.stream.bytesToString();
        Map<String, dynamic> errJson = {};
        try {
          errJson = jsonDecode(errText);
        } catch (_) {}
        final msg = errJson['error']?['message'] ?? errJson['error'] ?? 'API Error: ${streamedResponse.statusCode}';
        if (provider == LlmProviderType.ollama && msg.toString().contains('not found')) {
          throw Exception(
            'Local Ollama model "$effectiveModel" is not found.\n'
            'Please pull it with: `ollama pull $effectiveModel`'
          );
        }
        throw Exception(msg.toString());
      }

      final turnTextBuffer = StringBuffer();
      final Map<int, Map<String, dynamic>> toolCallsMap = {};

      await for (final line in streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (_isCancelled) break;
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final dataStr = trimmed.substring(5).trim();
        if (dataStr.isEmpty || dataStr == '[DONE]') continue;

        try {
          final data = jsonDecode(dataStr) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>? ?? [];
          if (choices.isEmpty) continue;

          final delta = choices[0]['delta'] as Map<String, dynamic>? ?? {};

          // Streaming text content
          if (delta.containsKey('content') && delta['content'] != null) {
            final textChunk = delta['content'].toString();
            turnTextBuffer.write(textChunk);
            finalResponseBuffer.write(textChunk);
            onContentUpdated(finalResponseBuffer.toString());
          }

          // Streaming tool calls
          if (delta.containsKey('tool_calls') && delta['tool_calls'] is List) {
            for (final tc in delta['tool_calls'] as List) {
              final index = tc['index'] as int? ?? 0;
              toolCallsMap.putIfAbsent(index, () => {
                'id': tc['id'] ?? const Uuid().v4(),
                'name': '',
                'arguments': StringBuffer(),
              });

              if (tc['id'] != null) {
                toolCallsMap[index]!['id'] = tc['id'];
              }
              final fn = tc['function'] as Map<String, dynamic>?;
              if (fn != null) {
                if (fn['name'] != null) {
                  toolCallsMap[index]!['name'] = '${toolCallsMap[index]!['name']}${fn['name']}';
                }
                if (fn['arguments'] != null) {
                  (toolCallsMap[index]!['arguments'] as StringBuffer).write(fn['arguments']);
                }
              }
            }
          }
        } catch (_) {}
      }

      if (_isCancelled) {
        finalResponseBuffer.writeln('\n\n🛑 *Task stopped by user.*');
        onContentUpdated(finalResponseBuffer.toString());
        return;
      }

      final accumulatedText = turnTextBuffer.toString();
      if (accumulatedText.isNotEmpty) {
        messages.add({'role': 'assistant', 'content': accumulatedText});
      }

      if (toolCallsMap.isEmpty) {
        break;
      }

      // Execute streaming tool calls
      for (final entry in toolCallsMap.entries) {
        if (_isCancelled) break;
        executedToolsCount++;
        final tData = entry.value;
        final callId = tData['id'] as String;
        final name = (tData['name'] as String).trim();
        final rawArgs = (tData['arguments'] as StringBuffer).toString();

        Map<String, dynamic> args = {};
        try {
          args = jsonDecode(rawArgs) as Map<String, dynamic>;
        } catch (_) {}

        final stepDesc = _getStepDescription(name, args);
        final toolLog = ToolCallLog(
          id: const Uuid().v4(),
          toolName: name,
          arguments: args,
          status: ToolStatus.running,
          stepDescription: stepDesc,
        );
        onToolStarted(toolLog);

        dynamic toolResult;
        try {
          final execResult = await _executeTool(name, args, turnId);
          toolResult = execResult['result'];
          toolLog.diffStats = execResult['diffStats'] as String?;
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

    // Auto-apply markdown actions (files, edits, commands emitted in markdown)
    if (executedToolsCount == 0 && !_isCancelled) {
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

  String _getStepDescription(String toolName, Map<String, dynamic> args) {
    switch (toolName) {
      case 'read_file':
        return '🔍 Reading ${args['path'] ?? 'file'}';
      case 'write_file':
        return '✍️ Writing ${args['path'] ?? 'file'}';
      case 'edit_file':
        return '📝 Editing ${args['path'] ?? 'file'}';
      case 'execute_terminal_command':
        return '💻 Executing `${args['command'] ?? 'command'}`';
      case 'search_codebase':
        return '🔎 Searching codebase for "${args['query'] ?? ''}"';
      case 'list_directory':
        return '📁 Listing directory ${args['path'] ?? '.'}';
      case 'move_file':
        return '🚚 Moving ${args['source_path']} -> ${args['destination_path']}';
      case 'delete_file':
        return '🗑️ Deleting ${args['path']}';
      default:
        return '⚙️ Running $toolName';
    }
  }

  /// Automatically parses and executes files, edits, and terminal commands emitted in markdown text responses
  Future<void> _autoApplyMarkdownActions({
    required String responseText,
    required String turnId,
    required Function(ToolCallLog) onToolStarted,
    required Function(ToolCallLog) onToolCompleted,
    required Function(String updatedContent) onContentUpdated,
  }) async {
    if (responseText.trim().isEmpty) return;

    final createdFiles = <String, String>{};
    final executedCommands = <String>[];
    int toolsRun = 0;

    // 1. Check for explicit JSON tool calls in text (e.g. emitted by Ollama / Qwen / OpenRouter)
    final jsonToolRegex = RegExp(
      r'\{\s*"name"\s*:\s*"(write_file|edit_file|delete_file|move_file|read_file|execute_terminal_command|search_codebase|list_directory)"\s*,\s*"(?:parameters|arguments)"\s*:\s*(\{[\s\S]*?\})\s*\}',
      caseSensitive: false,
    );
    for (final match in jsonToolRegex.allMatches(responseText)) {
      if (_isCancelled) break;
      final toolName = match.group(1)!;
      final rawArgs = match.group(2)!;
      try {
        final args = jsonDecode(rawArgs) as Map<String, dynamic>;
        final stepDesc = _getStepDescription(toolName, args);
        final toolLog = ToolCallLog(
          id: const Uuid().v4(),
          toolName: toolName,
          arguments: args,
          status: ToolStatus.running,
          stepDescription: stepDesc,
        );
        onToolStarted(toolLog);
        toolsRun++;
        try {
          final res = await _executeTool(toolName, args, turnId);
          toolLog.diffStats = res['diffStats'] as String?;
          toolLog.status = ToolStatus.success;
          toolLog.output = res['result'].toString();
          if (toolName == 'write_file' || toolName == 'edit_file') {
            createdFiles[args['path']?.toString() ?? 'file'] = toolLog.diffStats ?? '+';
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

    // 2. Extract and write all code blocks with associated file names
    final extractedFiles = extractMarkdownFileBlocks(responseText);
    for (final entry in extractedFiles.entries) {
      if (_isCancelled) break;
      final path = entry.key;
      final content = entry.value;

      if (createdFiles.containsKey(path)) continue;

      final stepDesc = '✍️ Writing $path';
      final toolLog = ToolCallLog(
        id: const Uuid().v4(),
        toolName: 'write_file',
        arguments: {'path': path, 'content': content},
        status: ToolStatus.running,
        stepDescription: stepDesc,
      );
      onToolStarted(toolLog);
      toolsRun++;

      try {
        final res = await _executeTool('write_file', {'path': path, 'content': content}, turnId);
        toolLog.diffStats = res['diffStats'] as String?;
        toolLog.status = ToolStatus.success;
        toolLog.output = 'Implemented: $path (${toolLog.diffStats ?? 'written'})';
        createdFiles[path] = toolLog.diffStats ?? '+';
      } catch (err) {
        toolLog.status = ToolStatus.failed;
        toolLog.output = 'Error writing $path: $err';
      }
      onToolCompleted(toolLog);
    }

    // 3. Extract and execute safe terminal commands (e.g. flutter pub get)
    final extractedCmds = extractMarkdownCommands(responseText);
    for (final cmd in extractedCmds) {
      if (_isCancelled) break;
      if (executedCommands.contains(cmd)) continue;
      final stepDesc = '💻 Running `$cmd`';
      final toolLog = ToolCallLog(
        id: const Uuid().v4(),
        toolName: 'execute_terminal_command',
        arguments: {'command': cmd},
        status: ToolStatus.running,
        stepDescription: stepDesc,
      );
      onToolStarted(toolLog);
      toolsRun++;

      try {
        final res = await _executeTool('execute_terminal_command', {'command': cmd}, turnId);
        toolLog.status = ToolStatus.success;
        toolLog.output = res['result'].toString();
        executedCommands.add(cmd);
      } catch (err) {
        toolLog.status = ToolStatus.failed;
        toolLog.output = 'Error executing $cmd: $err';
      }
      onToolCompleted(toolLog);
    }

    // Clean up response text to remove raw JSON code blocks and unfenced JSON tool objects
    var cleanText = responseText;
    cleanText = cleanText.replaceAll(
      RegExp(r'```(?:json)?\s*\{\s*"name"\s*:\s*"[a-zA-Z0-9_]+"\s*,\s*"(?:parameters|arguments)"\s*:\s*\{[\s\S]*?\}\s*\}\s*```', caseSensitive: false),
      '',
    );
    cleanText = cleanText.replaceAll(
      RegExp(r'\{\s*"name"\s*:\s*"(?:write_file|edit_file|delete_file|move_file|read_file|execute_terminal_command|search_codebase|list_directory)"\s*,\s*"(?:parameters|arguments)"\s*:\s*\{[\s\S]*?\}\s*\}', caseSensitive: false),
      '',
    );

    cleanText = cleanText.trim();

    if (toolsRun > 0) {
      if (cleanText.isEmpty) {
        cleanText = 'I have completed the requested workspace operations.';
      }
      onContentUpdated(cleanText);
    }
  }

  /// Aggressive extraction of file paths and code contents from any markdown format
  Map<String, String> extractMarkdownFileBlocks(String text) {
    final files = <String, String>{};
    final codeBlockRegex = RegExp(r'```([a-zA-Z0-9_\-]*)\r?\n([\s\S]*?)```');
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

      // 1. Check code block comments (e.g. // lib/main.dart or # pubspec.yaml)
      final codeLines = code.split('\n').take(4);
      for (final line in codeLines) {
        final commentMatch = RegExp(
          r'^(?:\/\/|#|<!--|\/\*)\s*(?:file:\s*|filepath:\s*)?([a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+)(?:\s*-->|\s*\*\/)?',
          caseSensitive: false,
        ).firstMatch(line.trim());
        if (commentMatch != null) {
          detectedPath = commentMatch.group(1);
          break;
        }
      }

        // 2. Look back in text before this code block (bounded by previous code block)
      if (detectedPath == null) {
        final prevEnd = i > 0 ? matches[i - 1].end : 0;
        final lookbackStart = math.max(prevEnd, match.start - 500);
        final lookback = text.substring(lookbackStart, match.start);

        // Check for directory hints (e.g. "in `android/app/src/main/res/drawable`" or "in lib/screens")
        final dirMatch = RegExp(
          r'(?:in|into|under|to|directory|folder)\s+(?:your\s+)?[`"]?([a-zA-Z0-9_\-]+(?:\/[a-zA-Z0-9_\-]+)+)[`"]?',
          caseSensitive: false,
        ).allMatches(lookback).lastOrNull;
        if (dirMatch != null) {
          dirHint = dirMatch.group(1);
        }

        // Check for full file paths with directory (e.g. android/app/src/main/res/drawable/splash_screen.xml)
        final fullPathMatch = RegExp(
          r'[`"]?([a-zA-Z0-9_\-]+(?:\/[a-zA-Z0-9_\-]+)+\.(?:dart|yaml|yml|json|xml|html|js|ts|kt|swift|py|sh|md))[`"]?',
          caseSensitive: false,
        ).allMatches(lookback).lastOrNull;

        // Match patterns like "main.dart (Example Content in lib/main.dart)" or "File: lib/main.dart"
        final pathInParenMatch = RegExp(
          r'(?:in|path|file:?)\s+[`"]?([a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+)[`"]?',
          caseSensitive: false,
        ).allMatches(lookback).lastOrNull;

        final standardFileHeaderMatch = RegExp(
          r'(?:###|##|#|\*\*|`|File:?)\s*([a-zA-Z0-9_\-./]+\.[a-zA-Z0-9]+)',
          caseSensitive: false,
        ).allMatches(lookback).lastOrNull;

        final anyFilePathMatch = RegExp(
          r'([a-zA-Z0-9_\-./]+\.(?:dart|yaml|yml|json|xml|html|js|ts|kt|swift|py|sh|md))',
          caseSensitive: false,
        ).allMatches(lookback).lastOrNull;

        if (fullPathMatch != null) {
          detectedPath = fullPathMatch.group(1);
        } else if (pathInParenMatch != null) {
          detectedPath = pathInParenMatch.group(1);
        } else if (standardFileHeaderMatch != null) {
          detectedPath = standardFileHeaderMatch.group(1);
        } else if (anyFilePathMatch != null) {
          detectedPath = anyFilePathMatch.group(1);
        }
      }

      // 3. Fallback heuristic from code content
      if (detectedPath == null) {
        if (lang == 'dart' || code.contains('package:flutter/')) {
          if (code.contains('void main()') || code.contains('runApp(')) {
            detectedPath = 'lib/main.dart';
          }
        } else if (lang == 'yaml' && (code.contains('dependencies:') || code.contains('flutter:'))) {
          detectedPath = 'pubspec.yaml';
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
            line.startsWith('pod ') ||
            (isShellBlock && (line.startsWith('git ') || line.startsWith('mkdir ') || line.startsWith('touch ')))) {
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
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll(':', '')
        .trim();

    if (clean.isEmpty) return null;

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
            return LlmModelInfo(
              id: id,
              displayName: '$id (Groq)',
              provider: LlmProviderType.groq,
              isFree: true,
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

  Future<Map<String, dynamic>> _executeTool(String name, Map<String, dynamic> args, String turnId) async {
    switch (name) {
      case 'read_file':
        final path = args['path'] as String;
        final start = args['start_line'] as int?;
        final end = args['end_line'] as int?;
        final content = await workspaceService.readFile(path, startLine: start, endLine: end);
        return {'result': content, 'diffStats': null};

      case 'write_file':
        final path = args['path'] as String;
        final content = args['content'] as String;
        await snapshotService.captureFileBeforeEdit(turnId, path);
        String oldContent = '';
        try {
          oldContent = await workspaceService.readFile(path);
        } catch (_) {}
        final res = await workspaceService.writeFile(path, content);
        await snapshotService.recordFileDiff(path, oldContent, content);

        String diffStats;
        if (oldContent.isEmpty) {
          diffStats = '+${content.split('\n').length}';
        } else {
          final removed = oldContent.split('\n').length;
          final added = content.split('\n').length;
          diffStats = '-$removed, +$added';
        }
        return {'result': res, 'diffStats': diffStats};

      case 'edit_file':
        final path = args['path'] as String;
        final target = args['target_content'] as String;
        final replacement = args['replacement_content'] as String;
        await snapshotService.captureFileBeforeEdit(turnId, path);
        final oldContent = await workspaceService.readFile(path);
        final res = await workspaceService.editFile(path, target, replacement);
        final newContent = await workspaceService.readFile(path);
        await snapshotService.recordFileDiff(path, oldContent, newContent);

        final removedLines = target.split('\n').length;
        final addedLines = replacement.split('\n').length;
        final diffStats = '-$removedLines, +$addedLines';
        return {'result': res, 'diffStats': diffStats};

      case 'move_file':
        final src = args['source_path'] as String;
        final dest = args['destination_path'] as String;
        await snapshotService.captureFileBeforeEdit(turnId, src);
        final res = await workspaceService.moveFile(src, dest);
        return {'result': res, 'diffStats': null};

      case 'delete_file':
        final path = args['path'] as String;
        await snapshotService.captureFileBeforeEdit(turnId, path);
        final res = await workspaceService.deleteFile(path);
        return {'result': res, 'diffStats': '-deleted'};

      case 'list_directory':
        final path = args['path'] as String? ?? '.';
        final items = await workspaceService.listDirectory(path);
        return {'result': {'items': items}, 'diffStats': null};

      case 'execute_terminal_command':
        final command = args['command'] as String;
        final workDir = workspaceService.rootPath ?? '.';
        final res = await terminalService.execute(command, workingDirectory: workDir);
        return {
          'result': {
            'command': res.command,
            'stdout': res.stdout,
            'stderr': res.stderr,
            'exitCode': res.exitCode,
            'durationMs': res.duration.inMilliseconds,
          },
          'diffStats': null,
        };

      case 'search_codebase':
        final query = args['query'] as String;
        final results = await ragService.search(query, topK: 5);
        return {
          'result': {
            'results': results
                .map((r) => {
                      'file': r.chunk.relativePath,
                      'startLine': r.chunk.startLine,
                      'endLine': r.chunk.endLine,
                      'preview': r.chunk.content,
                      'match': r.matchReason,
                    })
                .toList(),
          },
          'diffStats': null,
        };

      default:
        throw Exception('Unknown tool: $name');
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/tool_call_log.dart';
import 'rag_service.dart';
import 'terminal_service.dart';
import 'workspace_service.dart';

class GeminiAgentService {
  final WorkspaceService workspaceService;
  final TerminalService terminalService;
  final RagService ragService;

  GeminiAgentService({
    required this.workspaceService,
    required this.terminalService,
    required this.ragService,
  });

  List<Map<String, dynamic>> _buildToolsDeclarations() {
    return [
      {
        'function_declarations': [
          {
            'name': 'read_file',
            'description': 'Read the contents of a file within the workspace. Supports optional start_line and end_line for large files.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'path': {'type': 'STRING', 'description': 'Relative or absolute file path to read'},
                'start_line': {'type': 'INTEGER', 'description': 'Optional 1-indexed start line number'},
                'end_line': {'type': 'INTEGER', 'description': 'Optional 1-indexed end line number'},
              },
              'required': ['path'],
            },
          },
          {
            'name': 'write_file',
            'description': 'Create a new file or completely overwrite an existing file in the workspace.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'path': {'type': 'STRING', 'description': 'Relative or absolute file path to write to'},
                'content': {'type': 'STRING', 'description': 'Full text content to write into the file'},
              },
              'required': ['path', 'content'],
            },
          },
          {
            'name': 'edit_file',
            'description': 'Replace an exact snippet of text in a file with new content.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'path': {'type': 'STRING', 'description': 'Path of the file to edit'},
                'target_content': {'type': 'STRING', 'description': 'Exact substring to replace'},
                'replacement_content': {'type': 'STRING', 'description': 'New substring to insert'},
              },
              'required': ['path', 'target_content', 'replacement_content'],
            },
          },
          {
            'name': 'move_file',
            'description': 'Move or rename a file or directory in the workspace.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'source_path': {'type': 'STRING', 'description': 'Source file or directory path'},
                'destination_path': {'type': 'STRING', 'description': 'Destination file or directory path'},
              },
              'required': ['source_path', 'destination_path'],
            },
          },
          {
            'name': 'delete_file',
            'description': 'Delete a file or directory in the workspace.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'path': {'type': 'STRING', 'description': 'Path to the file or directory to delete'},
              },
              'required': ['path'],
            },
          },
          {
            'name': 'list_directory',
            'description': 'List files and subdirectories inside a given directory in the workspace.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'path': {'type': 'STRING', 'description': 'Directory path to list. Use "." for root workspace directory'},
              },
              'required': ['path'],
            },
          },
          {
            'name': 'execute_terminal_command',
            'description': 'Execute a shell command (bash/zsh on mac/linux, cmd on windows) inside the workspace directory. Use for running tests, build tools, git, package managers, file searches, etc.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'command': {'type': 'STRING', 'description': 'The shell command to run'},
              },
              'required': ['command'],
            },
          },
          {
            'name': 'search_codebase',
            'description': 'Perform a semantic and keyword RAG search across the entire indexed workspace to find relevant code snippets and files.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'query': {'type': 'STRING', 'description': 'Search query or concept to find in codebase'},
              },
              'required': ['query'],
            },
          },
        ]
      }
    ];
  }

  String _buildSystemPrompt() {
    final root = workspaceService.rootPath ?? 'No directory selected yet';
    return '''
You are an expert AI Coding Agent with full autonomous capabilities to inspect, edit, build, and execute code within the user's workspace.
Current Workspace Directory: $root

CORE RESPONSIBILITIES:
1. ALWAYS inspect the workspace files or codebase before assuming things. Use `search_codebase`, `list_directory`, and `read_file` to understand the structure.
2. You can read, write, edit, move, and delete files using the specialized tools.
3. You can execute terminal commands inside the workspace using `execute_terminal_command` (e.g. running compilers, linters, tests, git commands).
4. When writing code, write clean, well-structured, production-ready code.
5. If you perform file modifications or run commands, report the outcome clearly to the user.
6. If creating an HTML/Web UI component or interactive widget, output clean HTML/CSS/JS inside a ```html ``` block so the app's right-hand Web View panel can render it directly!
''';
  }

  Future<void> runAgentTurn({
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
    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      onContentUpdated(
        '⚠️ **Gemini API Key Required**\n\n'
        'Please enter your Gemini API key in the top bar or settings dialog (⚙️) to enable the agent to analyze files, call tools, and execute terminal commands.\n\n'
        '*You can get a free API key at [Google AI Studio](https://aistudio.google.com).*',
      );
      return;
    }

    // Step 1: Automatic RAG Pre-Retrieval (Context Enrichment)
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

    // Build raw JSON contents list for Gemini REST API
    final contents = <Map<String, dynamic>>[];

    // Add previous conversation history
    for (final msg in conversationHistory) {
      if (msg.role == MessageRole.user) {
        contents.add({
          'role': 'user',
          'parts': [{'text': msg.content}],
        });
      } else if (msg.role == MessageRole.assistant) {
        if (msg.content.trim().isNotEmpty) {
          contents.add({
            'role': 'model',
            'parts': [{'text': msg.content}],
          });
        }
      }
    }

    // Add current user prompt
    contents.add({
      'role': 'user',
      'parts': [{'text': promptWithRag}],
    });

    final tools = _buildToolsDeclarations();
    final systemPrompt = _buildSystemPrompt();

    int loopCount = 0;
    const maxLoops = 15;
    final finalResponseBuffer = StringBuffer();

    while (loopCount < maxLoops) {
      loopCount++;

      final responseJson = await _callGeminiApi(
        apiKey: apiKey,
        modelName: modelName,
        temperature: temperature,
        systemPrompt: systemPrompt,
        contents: contents,
        tools: tools,
      );

      final candidates = responseJson['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        final errorMsg = responseJson['error']?['message'] ?? 'No candidate response returned from Gemini.';
        throw Exception(errorMsg);
      }

      final candidate = candidates[0] as Map<String, dynamic>;
      final candidateContent = candidate['content'] as Map<String, dynamic>? ?? {};
      final parts = (candidateContent['parts'] as List<dynamic>?) ?? [];

      // CRITICAL: Preserve the exact raw candidate content (including thought_signature) in the conversation history!
      contents.add(Map<String, dynamic>.from(candidateContent));

      // Extract text and function calls
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

      if (functionCalls.isEmpty) {
        break; // Agent finished all tool calls
      }

      // Execute each tool call and collect function responses
      final functionResponseParts = <Map<String, dynamic>>[];

      for (final call in functionCalls) {
        final callName = call['name'] as String? ?? '';
        final callArgs = (call['args'] as Map<String, dynamic>?) ?? {};

        final toolLog = ToolCallLog(
          id: const Uuid().v4(),
          toolName: callName,
          arguments: callArgs,
          status: ToolStatus.running,
        );

        onToolStarted(toolLog);

        dynamic toolResult;
        try {
          toolResult = await _executeTool(callName, callArgs);
          toolLog.status = ToolStatus.success;
          toolLog.output = toolResult.toString();
        } catch (err) {
          toolLog.status = ToolStatus.failed;
          toolLog.output = 'Error executing $callName: $err';
          toolResult = {'error': err.toString()};
        }

        onToolCompleted(toolLog);

        functionResponseParts.add({
          'functionResponse': {
            'name': callName,
            'response': toolResult is Map<String, dynamic> ? toolResult : {'result': toolResult.toString()},
          }
        });
      }

      // Feed function responses back under 'user' role with proper functionResponse parts
      contents.add({
        'role': 'user',
        'parts': functionResponseParts,
      });
    }

    if (finalResponseBuffer.isEmpty) {
      onContentUpdated('Agent completed task.');
    }
  }

  Future<Map<String, dynamic>> _callGeminiApi({
    required String apiKey,
    required String modelName,
    required double temperature,
    required String systemPrompt,
    required List<Map<String, dynamic>> contents,
    required List<Map<String, dynamic>> tools,
  }) async {
    // Clean model name (handle models/ prefix if present)
    final cleanModel = modelName.startsWith('models/') ? modelName.substring(7) : modelName;
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$cleanModel:generateContent?key=$apiKey');

    final payload = {
      'system_instruction': {
        'parts': [{'text': systemPrompt}]
      },
      'contents': contents,
      'tools': tools,
      'generationConfig': {
        'temperature': temperature,
      },
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final message = responseBody['error']?['message'] ?? 'Gemini API Error: Status ${response.statusCode}';
      throw Exception(message);
    }

    return responseBody;
  }

  Future<dynamic> _executeTool(String name, Map<String, dynamic> args) async {
    switch (name) {
      case 'read_file':
        final path = args['path'] as String;
        final start = args['start_line'] as int?;
        final end = args['end_line'] as int?;
        return await workspaceService.readFile(path, startLine: start, endLine: end);

      case 'write_file':
        final path = args['path'] as String;
        final content = args['content'] as String;
        return await workspaceService.writeFile(path, content);

      case 'edit_file':
        final path = args['path'] as String;
        final target = args['target_content'] as String;
        final replacement = args['replacement_content'] as String;
        return await workspaceService.editFile(path, target, replacement);

      case 'move_file':
        final src = args['source_path'] as String;
        final dest = args['destination_path'] as String;
        return await workspaceService.moveFile(src, dest);

      case 'delete_file':
        final path = args['path'] as String;
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

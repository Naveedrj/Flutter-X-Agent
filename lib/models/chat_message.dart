import 'package:uuid/uuid.dart';
import 'tool_call_log.dart';

enum MessageRole {
  user,
  assistant,
  system,
}

class ChatMessage {
  final String id;
  final MessageRole role;
  String content;
  final List<ToolCallLog> toolCalls;
  final List<String> ragSources;
  final DateTime timestamp;
  bool isProcessing;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    List<ToolCallLog>? toolCalls,
    List<String>? ragSources,
    DateTime? timestamp,
    this.isProcessing = false,
  })  : id = id ?? const Uuid().v4(),
        toolCalls = toolCalls ?? [],
        ragSources = ragSources ?? [],
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'toolCalls': toolCalls.map((t) => t.toJson()).toList(),
        'ragSources': ragSources,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String?,
        role: MessageRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => MessageRole.user,
        ),
        content: json['content'] as String? ?? '',
        toolCalls: (json['toolCalls'] as List<dynamic>?)
                ?.map((t) => ToolCallLog.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
        ragSources: (json['ragSources'] as List<dynamic>?)
                ?.map((s) => s.toString())
                .toList() ??
            [],
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        isProcessing: false,
      );
}

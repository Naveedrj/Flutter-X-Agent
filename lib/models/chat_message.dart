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
  String? statusStep; // e.g. "🔍 Reading lib/main.dart...", "✍️ Writing lib/screens/login.dart (+42 lines)"

  // Adversarial Debate Metadata
  String? speakerTag; // 'blue', 'red', 'consensus'
  String? modelName;
  int? roundNumber;
  List<String> vulnerabilities;
  List<String> optimizations;
  String? hardenedCode;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    List<ToolCallLog>? toolCalls,
    List<String>? ragSources,
    DateTime? timestamp,
    this.isProcessing = false,
    this.statusStep,
    this.speakerTag,
    this.modelName,
    this.roundNumber,
    List<String>? vulnerabilities,
    List<String>? optimizations,
    this.hardenedCode,
  })  : id = id ?? const Uuid().v4(),
        toolCalls = toolCalls ?? [],
        ragSources = ragSources ?? [],
        vulnerabilities = vulnerabilities ?? [],
        optimizations = optimizations ?? [],
        timestamp = timestamp ?? DateTime.now();

  bool get isBlueTeam => speakerTag == 'blue' || speakerTag == 'blue_defense';
  bool get isRedTeam => speakerTag == 'red';
  bool get isConsensus => speakerTag == 'consensus';

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'toolCalls': toolCalls.map((t) => t.toJson()).toList(),
        'ragSources': ragSources,
        'timestamp': timestamp.toIso8601String(),
        'statusStep': statusStep,
        'speakerTag': speakerTag,
        'modelName': modelName,
        'roundNumber': roundNumber,
        'vulnerabilities': vulnerabilities,
        'optimizations': optimizations,
        'hardenedCode': hardenedCode,
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
        statusStep: json['statusStep'] as String?,
        speakerTag: json['speakerTag'] as String?,
        modelName: json['modelName'] as String?,
        roundNumber: json['roundNumber'] as int?,
        vulnerabilities: (json['vulnerabilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        optimizations: (json['optimizations'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        hardenedCode: json['hardenedCode'] as String?,
      );
}

import 'dart:convert';

enum ToolStatus {
  running,
  success,
  failed,
}

class ToolCallLog {
  final String id;
  final String toolName;
  final Map<String, dynamic> arguments;
  String? output;
  ToolStatus status;
  final DateTime timestamp;

  ToolCallLog({
    required this.id,
    required this.toolName,
    required this.arguments,
    this.output,
    this.status = ToolStatus.running,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'toolName': toolName,
        'arguments': arguments,
        'output': output,
        'status': status.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ToolCallLog.fromJson(Map<String, dynamic> json) => ToolCallLog(
        id: json['id'] as String? ?? '',
        toolName: json['toolName'] as String? ?? '',
        arguments: json['arguments'] != null
            ? Map<String, dynamic>.from(json['arguments'] as Map)
            : {},
        output: json['output'] as String?,
        status: ToolStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ToolStatus.success,
        ),
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  String get argumentsFormatted {
    try {
      return const JsonEncoder.withIndent('  ').convert(arguments);
    } catch (_) {
      return arguments.toString();
    }
  }
}

import 'package:uuid/uuid.dart';
import 'chat_message.dart';

class ChatSession {
  final String id;
  String title;
  final String workspacePath;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;
  String? webPreviewHtml;

  ChatSession({
    String? id,
    required this.title,
    required this.workspacePath,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.webPreviewHtml,
  })  : id = id ?? const Uuid().v4(),
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'workspacePath': workspacePath,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'webPreviewHtml': webPreviewHtml,
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String?,
        title: json['title'] as String? ?? 'Untitled Session',
        workspacePath: json['workspacePath'] as String? ?? '',
        messages: (json['messages'] as List<dynamic>?)
                ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        webPreviewHtml: json['webPreviewHtml'] as String?,
      );
}

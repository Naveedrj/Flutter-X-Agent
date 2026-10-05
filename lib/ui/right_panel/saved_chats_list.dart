import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../app_theme.dart';

class SavedChatsList extends StatelessWidget {
  const SavedChatsList({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final sessions = chatProvider.sessions;
    final activeId = chatProvider.activeSession?.id;

    return Container(
      color: AppTheme.darkBg,
      child: Column(
        children: [
          // Header / New Chat action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF131D30),
              border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 18, color: AppTheme.primaryLight),
                const SizedBox(width: 8),
                Text(
                  'SAVED SESSIONS (${sessions.length})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 28),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('New Chat', style: TextStyle(fontSize: 11)),
                  onPressed: () => chatProvider.createNewSession(),
                ),
              ],
            ),
          ),

          // List of saved sessions
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 40, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 10),
                        const Text(
                          'No saved chat sessions',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppTheme.darkBorder),
                          ),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Start First Chat'),
                          onPressed: () => chatProvider.createNewSession(),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isActive = session.id == activeId;
                      final timeStr = DateFormat('MMM d, h:mm a').format(session.updatedAt);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        color: isActive ? const Color(0xFF1E293B) : const Color(0xFF141D30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isActive ? AppTheme.primary : AppTheme.darkBorder,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => chatProvider.selectSession(session.id),
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Row(
                              children: [
                                Icon(
                                  isActive ? Icons.chat : Icons.chat_bubble_outline,
                                  size: 16,
                                  color: isActive ? AppTheme.primaryLight : Colors.white54,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            '${session.messages.length} msgs',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontFamily: 'monospace',
                                              color: Colors.white.withOpacity(0.4),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '• $timeStr',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white.withOpacity(0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 15, color: Colors.white38),
                                  splashRadius: 12,
                                  tooltip: 'Delete Chat',
                                  onPressed: () => chatProvider.deleteSession(session.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

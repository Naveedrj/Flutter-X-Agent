import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/workspace_provider.dart';
import 'services/gemini_agent_service.dart';
import 'services/rag_service.dart';
import 'services/storage_service.dart';
import 'services/terminal_service.dart';
import 'services/workspace_service.dart';
import 'ui/app_theme.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Storage Service
  final storageService = StorageService();
  await storageService.init();

  // Initialize Core Services
  final workspaceService = WorkspaceService();
  final terminalService = TerminalService();
  final ragService = RagService(workspaceService: workspaceService);
  final geminiAgentService = GeminiAgentService(
    workspaceService: workspaceService,
    terminalService: terminalService,
    ragService: ragService,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(storageService: storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkspaceProvider(
            workspaceService: workspaceService,
            terminalService: terminalService,
            ragService: ragService,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProxyProvider2<SettingsProvider, WorkspaceProvider, ChatProvider>(
          create: (context) => ChatProvider(
            storageService: storageService,
            geminiAgentService: geminiAgentService,
            settingsProvider: context.read<SettingsProvider>(),
            workspaceProvider: context.read<WorkspaceProvider>(),
          ),
          update: (context, settings, workspace, previous) =>
              previous ??
              ChatProvider(
                storageService: storageService,
                geminiAgentService: geminiAgentService,
                settingsProvider: settings,
                workspaceProvider: workspace,
              ),
        ),
      ],
      child: const AgenticApp(),
    ),
  );
}

class AgenticApp extends StatelessWidget {
  const AgenticApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'AGENTIC • AI Workspace & Codebase Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}

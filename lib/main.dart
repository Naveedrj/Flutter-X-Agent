import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/adversarial_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/workspace_provider.dart';
import 'services/adversarial_service.dart';
import 'services/auto_debug_service.dart';
import 'services/git_service.dart';
import 'services/rag_service.dart';
import 'services/snapshot_service.dart';
import 'services/storage_service.dart';
import 'services/terminal_service.dart';
import 'services/unified_agent_service.dart';
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
  final snapshotService = SnapshotService(workspaceService: workspaceService);
  final gitService = GitService(terminalService: terminalService);

  final agentService = UnifiedAgentService(
    workspaceService: workspaceService,
    terminalService: terminalService,
    ragService: ragService,
    snapshotService: snapshotService,
  );

  final autoDebugService = AutoDebugService(
    workspaceService: workspaceService,
    terminalService: terminalService,
    agentService: agentService,
  );

  final adversarialService = AdversarialService(
    workspaceService: workspaceService,
    snapshotService: snapshotService,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AdversarialProvider(
            adversarialService: adversarialService,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(
            storageService: storageService,
            agentService: agentService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WorkspaceProvider(
            workspaceService: workspaceService,
            terminalService: terminalService,
            ragService: ragService,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProxyProvider3<SettingsProvider, WorkspaceProvider, AdversarialProvider, ChatProvider>(
          create: (context) => ChatProvider(
            storageService: storageService,
            agentService: agentService,
            autoDebugService: autoDebugService,
            gitService: gitService,
            snapshotService: snapshotService,
            adversarialService: adversarialService,
            settingsProvider: context.read<SettingsProvider>(),
            workspaceProvider: context.read<WorkspaceProvider>(),
            adversarialProvider: context.read<AdversarialProvider>(),
          ),
          update: (context, settings, workspace, adversarial, previous) =>
              previous ??
              ChatProvider(
                storageService: storageService,
                agentService: agentService,
                autoDebugService: autoDebugService,
                gitService: gitService,
                snapshotService: snapshotService,
                adversarialService: adversarialService,
                settingsProvider: settings,
                workspaceProvider: workspace,
                adversarialProvider: adversarial,
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
      title: 'Flutter-X-Agent • Autonomous AI Workspace IDE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}

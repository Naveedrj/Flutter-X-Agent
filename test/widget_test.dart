import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agentic_app/services/storage_service.dart';
import 'package:agentic_app/services/workspace_service.dart';
import 'package:agentic_app/services/terminal_service.dart';
import 'package:agentic_app/services/rag_service.dart';
import 'package:agentic_app/services/snapshot_service.dart';
import 'package:agentic_app/services/git_service.dart';
import 'package:agentic_app/services/unified_agent_service.dart';
import 'package:agentic_app/services/auto_debug_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Services initialization test', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();

    expect(storage.getApiKey(), StorageService.defaultApiKeyPlaceholder);
    expect(storage.getModel(), StorageService.defaultModel);

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

    expect(agentService, isNotNull);
    expect(autoDebugService, isNotNull);
    expect(gitService, isNotNull);
  });
}

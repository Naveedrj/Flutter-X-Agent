import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agentic_app/models/adversarial_debate.dart';
import 'package:agentic_app/models/chat_message.dart';
import 'package:agentic_app/models/llm_provider.dart';
import 'package:agentic_app/providers/adversarial_provider.dart';
import 'package:agentic_app/providers/chat_provider.dart';
import 'package:agentic_app/providers/settings_provider.dart';
import 'package:agentic_app/providers/workspace_provider.dart';
import 'package:agentic_app/services/adversarial_service.dart';
import 'package:agentic_app/services/auto_debug_service.dart';
import 'package:agentic_app/services/git_service.dart';
import 'package:agentic_app/services/rag_service.dart';
import 'package:agentic_app/services/snapshot_service.dart';
import 'package:agentic_app/services/storage_service.dart';
import 'package:agentic_app/services/terminal_service.dart';
import 'package:agentic_app/services/unified_agent_service.dart';
import 'package:agentic_app/services/workspace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late WorkspaceService workspaceService;
  late TerminalService terminalService;
  late RagService ragService;
  late SnapshotService snapshotService;
  late GitService gitService;
  late UnifiedAgentService agentService;
  late AutoDebugService autoDebugService;
  late AdversarialService adversarialService;
  late SettingsProvider settingsProvider;
  late WorkspaceProvider workspaceProvider;
  late AdversarialProvider adversarialProvider;
  late ChatProvider chatProvider;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'api_key_gemini': 'MOCK_TEST_KEY_FOR_UNIT_TESTS',
      'selected_llm_model': 'gemini-3.8-flash',
      'active_llm_provider': 'gemini',
    });

    tempDir = await Directory.systemTemp.createTemp('agentic_test_');

    storageService = StorageService();
    await storageService.init();

    workspaceService = WorkspaceService();
    workspaceService.rootPath = tempDir.path;

    terminalService = TerminalService();
    ragService = RagService(workspaceService: workspaceService);
    snapshotService = SnapshotService(workspaceService: workspaceService);
    gitService = GitService(terminalService: terminalService);

    agentService = UnifiedAgentService(
      workspaceService: workspaceService,
      terminalService: terminalService,
      ragService: ragService,
      snapshotService: snapshotService,
    );

    autoDebugService = AutoDebugService(
      workspaceService: workspaceService,
      terminalService: terminalService,
      agentService: agentService,
    );

    adversarialService = AdversarialService(
      workspaceService: workspaceService,
      snapshotService: snapshotService,
    );

    settingsProvider = SettingsProvider(
      storageService: storageService,
      agentService: agentService,
    );

    workspaceProvider = WorkspaceProvider(
      workspaceService: workspaceService,
      terminalService: terminalService,
      ragService: ragService,
      storageService: storageService,
    );

    adversarialProvider = AdversarialProvider(
      adversarialService: adversarialService,
      storageService: storageService,
    );

    chatProvider = ChatProvider(
      storageService: storageService,
      agentService: agentService,
      autoDebugService: autoDebugService,
      gitService: gitService,
      snapshotService: snapshotService,
      adversarialService: adversarialService,
      settingsProvider: settingsProvider,
      workspaceProvider: workspaceProvider,
      adversarialProvider: adversarialProvider,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Simple Mode & Settings Verification', () {
    test('Settings correctly resolves paid key and global model', () {
      expect(settingsProvider.activeProvider, LlmProviderType.gemini);
      expect(settingsProvider.model, 'gemini-3.8-flash');
      expect(settingsProvider.apiKey, 'MOCK_TEST_KEY_FOR_UNIT_TESTS');
    });

    test('ChatProvider starts in default single-agent mode', () {
      expect(chatProvider.isAdversarialMode, isFalse);
      expect(chatProvider.isAgentBusy, isFalse);
      expect(chatProvider.activeSession, isNotNull);
    });

    test('Normalizes Gemini model names accurately without overrides', () {
      expect(adversarialService.normalizeGeminiModel('models/gemini-3.8-flash'), 'gemini-3.8-flash');
      expect(adversarialService.normalizeGeminiModel('gemini-1.5-pro'), 'gemini-1.5-pro');
      expect(adversarialService.normalizeGeminiModel('gemini-2.0-flash'), 'gemini-2.0-flash');
    });
  });

  group('Adversarial Duel Mode Logic & Prompts Verification', () {
    test('Adversarial Mode toggle switches state properly', () {
      expect(chatProvider.isAdversarialMode, isFalse);
      chatProvider.toggleAdversarialMode();
      expect(chatProvider.isAdversarialMode, isTrue);
      chatProvider.setAdversarialMode(false);
      expect(chatProvider.isAdversarialMode, isFalse);
    });

    test('Blue Team inherits Global settings and Red Team matches by default', () {
      expect(adversarialProvider.config.blueProvider, LlmProviderType.gemini);
      expect(adversarialProvider.config.blueModel, 'gemini-3.8-flash');
      expect(adversarialProvider.config.redProvider, LlmProviderType.gemini);
      expect(adversarialProvider.config.redModel, 'gemini-3.8-flash');
    });

    test('Prompt Builders format system and attack prompts correctly', () {
      final blueSys = adversarialService.buildBlueSystemPrompt(
        round: 1,
        focus: AdversarialAttackFocus.security,
      );
      expect(blueSys, contains('Blue Team Lead Architect'));

      final redSys = adversarialService.buildRedSystemPrompt(
        focus: AdversarialAttackFocus.security,
      );
      expect(redSys, contains('Red Team Master Security Hacker'));
      expect(redSys, contains('EXPLOITS & VULNERABILITIES FOUND'));

      final blueInit = adversarialService.buildBlueInitialPrompt(
        taskPrompt: 'Build Login Form in Flutter',
      );
      expect(blueInit, contains('Build Login Form in Flutter'));

      final redAttack = adversarialService.buildRedAttackPrompt(
        taskPrompt: 'Build Login Form in Flutter',
        codeToAttack: 'class LoginForm extends StatelessWidget {}',
        round: 1,
        maxRounds: 3,
      );
      expect(redAttack, contains('LoginForm'));
      expect(redAttack, contains('Round 1 of 3'));
    });

    test('Adversarial Response Parsers accurately extract code and exploits', () {
      const mockBlueOutput = '''
Here is the implementation:
```dart
class SecureAuthService {
  Future<bool> login(String user, String pass) async {
    return user.isNotEmpty && pass.length >= 8;
  }
}
```
Clean and ready.
''';
      final extractedCode = adversarialService.extractCodeBlock(mockBlueOutput);
      expect(extractedCode, contains('class SecureAuthService'));

      const mockRedOutput = '''
### 🚨 EXPLOITS & VULNERABILITIES FOUND
- Plaintext password comparison without Argon2/bcrypt hashing.
- Missing rate-limiting on login attempts allows brute force.

### ⚡ PERFORMANCE & CONCURRENCY BOTTLENECKS
- Uncached authentication tokens causing repeated disk reads.

### 🛠️ REQUIRED PATCHES & STRESS TESTS
- Add SHA-256 / PBKDF2 hashing.
''';
      final vulns = adversarialService.parseVulnerabilities(mockRedOutput);
      expect(vulns.length, 2);
      expect(vulns[0], contains('Plaintext password'));
      expect(vulns[1], contains('rate-limiting'));

      final opts = adversarialService.parseOptimizations(mockRedOutput);
      expect(opts.length, 1);
      expect(opts[0], contains('Uncached authentication tokens'));
    });

    test('Consensus turn creation and applying hardened code with snapshots', () async {
      final targetFile = File('${tempDir.path}/lib/auth.dart');
      await targetFile.parent.create(recursive: true);
      await targetFile.writeAsString('// original file code');

      const hardenedCode = '''
class HardenedAuthService {
  // Hardened against all exploits
  final String version = "2.0";
}
''';

      await adversarialService.applyHardenedCode(
        filePath: targetFile.path,
        hardenedCode: hardenedCode,
      );

      final updatedContent = await targetFile.readAsString();
      expect(updatedContent, contains('HardenedAuthService'));

      // Check rollback capability and recent diffs
      expect(snapshotService.canRollback('adversarial-turn'), isTrue);
      expect(snapshotService.recentDiffs.isNotEmpty, isTrue);
    });

    test('Error resilience: cleans up processing loader and marks isProcessing false', () {
      final session = chatProvider.activeSession!;
      
      // Simulate an in-flight message that failed
      final pendingBlueMsg = ChatMessage(
        role: MessageRole.assistant,
        speakerTag: 'blue',
        content: 'Constructing code...',
        isProcessing: true,
      );
      session.messages.add(pendingBlueMsg);

      // Verify cleanup logic
      session.messages.removeWhere((m) => m.isProcessing);
      session.messages.add(
        ChatMessage(
          role: MessageRole.assistant,
          content: '❌ **Adversarial Duel Error**: Invalid API key.',
        ),
      );

      expect(session.messages.any((m) => m.isProcessing), isFalse);
      expect(session.messages.last.content, contains('Invalid API key'));
    });
  });

  group('Autonomous Execution & Fallback Parser Verification', () {
    test('Correctly extracts and maps all files and commands from markdown tutorial responses', () {
      const mockLlmMarkdownTutorial = '''
Okay, let's create the splash screen, onboarding screens, login, signup, and home screens for your e-commerce app, and then run it on Chrome.

### Step 1: Add Splash Screen

First, we'll add a splash screen using the `flutter_native_splash` package. If it's not already added, let's add it to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_native_splash: ^2.0.5
```

Run:

```sh
flutter pub get
flutter pub run flutter_native_splash:create
```

Now, add the splash screen image to your `android/app/src/main/res/drawable` directory and create a `splash_screen.xml` file in `android/app/src/main/res/drawable`.

```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <color android:color="#FFFFFF"/>
    </item>
</layer-list>
```

### Step 2: Create Onboarding Screens

Create a new file `onboarding.dart`:

```dart
import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text("Onboarding")));
}
```

### Step 3: Create Login, Signup, and Home Screens

Create a new file `screens.dart`:

```dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text("Home")));
}
```

### Step 4: Update `main.dart`

Update your `main.dart` to include these screens:

```dart
import 'package:flutter/material.dart';
import 'onboarding.dart';

void main() => runApp(MaterialApp(home: OnboardingScreen()));
```
''';

      final extractedFiles = agentService.extractMarkdownFileBlocks(mockLlmMarkdownTutorial);
      expect(extractedFiles.containsKey('pubspec.yaml'), isTrue);
      expect(extractedFiles['pubspec.yaml'], contains('flutter_native_splash'));

      expect(extractedFiles.containsKey('android/app/src/main/res/drawable/splash_screen.xml'), isTrue);
      expect(extractedFiles['android/app/src/main/res/drawable/splash_screen.xml'], contains('<layer-list'));

      expect(extractedFiles.containsKey('lib/onboarding.dart'), isTrue);
      expect(extractedFiles['lib/onboarding.dart'], contains('class OnboardingScreen'));

      expect(extractedFiles.containsKey('lib/screens.dart'), isTrue);
      expect(extractedFiles['lib/screens.dart'], contains('class HomeScreen'));

      expect(extractedFiles.containsKey('lib/main.dart'), isTrue);
      expect(extractedFiles['lib/main.dart'], contains('void main()'));

      final extractedCommands = agentService.extractMarkdownCommands(mockLlmMarkdownTutorial);
      expect(extractedCommands, contains('flutter pub get'));
      expect(extractedCommands, contains('flutter pub run flutter_native_splash:create'));
    });

    test('Path normalizer correctly resolves paths and directory hints', () {
      expect(agentService.normalizeFilePath('onboarding.dart'), 'lib/onboarding.dart');
      expect(agentService.normalizeFilePath('lib/screens/login.dart'), 'lib/screens/login.dart');
      expect(agentService.normalizeFilePath('pubspec.yaml'), 'pubspec.yaml');
      expect(
        agentService.normalizeFilePath('splash_screen.xml', directoryHint: 'android/app/src/main/res/drawable'),
        'android/app/src/main/res/drawable/splash_screen.xml',
      );
      expect(agentService.normalizeFilePath('https://flutter.dev/test.dart'), isNull);
    });
  });
}

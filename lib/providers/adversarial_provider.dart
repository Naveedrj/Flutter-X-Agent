import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/adversarial_debate.dart';
import '../models/llm_provider.dart';
import '../services/adversarial_service.dart';
import '../services/storage_service.dart';

class AdversarialProvider extends ChangeNotifier {
  final AdversarialService adversarialService;
  final StorageService storageService;

  AdversarialConfig _config = AdversarialConfig(
    blueProvider: LlmProviderType.groq,
    blueModel: 'qwen-2.5-coder-32b',
    blueApiKey: '',
    redProvider: LlmProviderType.groq,
    redModel: 'llama-3.3-70b-versatile',
    redApiKey: '',
    maxRounds: 3,
    focus: AdversarialAttackFocus.comprehensive,
  );

  AdversarialSession? _currentSession;
  final List<AdversarialSession> _history = [];
  bool _isDuelRunning = false;
  String? _statusMessage;

  AdversarialConfig get config => _config;
  AdversarialSession? get currentSession => _currentSession;
  List<AdversarialSession> get history => _history;
  bool get isDuelRunning => _isDuelRunning;
  String? get statusMessage => _statusMessage;

  AdversarialProvider({
    required this.adversarialService,
    required this.storageService,
  }) {
    _initFromStorage();
  }

  void _initFromStorage() {
    final activeProvider = storageService.getActiveProvider();
    final key = storageService.getApiKey(provider: activeProvider);
    final model = storageService.getModel();

    // Default Blue team to active provider
    _config.blueProvider = activeProvider;
    _config.blueModel = model;
    _config.blueApiKey = key;

    // Default Red team to the SAME provider and model as Blue Team
    _config.redProvider = activeProvider;
    _config.redModel = model;
    _config.redApiKey = key;
    notifyListeners();
  }

  void updateConfig(AdversarialConfig newConfig) {
    _config = newConfig;
    notifyListeners();
  }

  Future<void> startDuel({
    required String taskPrompt,
    String? targetFilePath,
    String? existingFileContent,
  }) async {
    if (_isDuelRunning || taskPrompt.trim().isEmpty) return;

    _isDuelRunning = true;
    _statusMessage = 'Initializing Adversarial Arena...';

    final session = AdversarialSession(
      id: const Uuid().v4(),
      taskPrompt: taskPrompt,
      config: _config.copyWith(),
      targetFilePath: targetFilePath,
      createdAt: DateTime.now(),
    );

    _currentSession = session;
    _history.insert(0, session);
    notifyListeners();

    try {
      await adversarialService.runAdversarialDuel(
        session: session,
        existingFileContext: existingFileContent,
        onTurnAdded: (turn) {
          notifyListeners();
        },
        onStatusChanged: (status, msg) {
          session.status = status;
          _statusMessage = msg;
          notifyListeners();
        },
      );
    } catch (e) {
      session.status = AdversarialSessionStatus.error;
      session.errorMessage = e.toString();
      _statusMessage = 'Duel encountered an error: $e';
    } finally {
      _isDuelRunning = false;
      notifyListeners();
    }
  }

  Future<void> applyHardenedCode(String filePath) async {
    if (_currentSession?.finalHardenedCode == null) return;
    await adversarialService.applyHardenedCode(
      filePath: filePath,
      hardenedCode: _currentSession!.finalHardenedCode!,
    );
    notifyListeners();
  }

  void clearCurrentSession() {
    _currentSession = null;
    _statusMessage = null;
    notifyListeners();
  }
}

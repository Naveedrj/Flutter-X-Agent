import 'package:flutter/foundation.dart';
import '../models/llm_provider.dart';
import '../services/storage_service.dart';
import '../services/unified_agent_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService storageService;
  final UnifiedAgentService agentService;

  LlmProviderType _activeProvider = LlmProviderType.groq;
  String _apiKey = StorageService.defaultApiKeyPlaceholder;
  String _model = StorageService.defaultModel;
  double _temperature = 0.4;
  bool _isDarkMode = true;
  bool _isFetchingModels = false;

  final List<LlmModelInfo> _availableModels = List.from(LlmProviderUtils.defaultModels);

  SettingsProvider({
    required this.storageService,
    required this.agentService,
  }) {
    _loadSettings();
  }

  LlmProviderType get activeProvider => _activeProvider;
  String get apiKey => _apiKey;
  String get model => _model;
  double get temperature => _temperature;
  bool get isDarkMode => _isDarkMode;
  bool get isFetchingModels => _isFetchingModels;
  List<LlmModelInfo> get availableModels => _availableModels;

  List<LlmModelInfo> get currentProviderModels =>
      _availableModels.where((m) => m.provider == _activeProvider).toList();

  bool get hasValidApiKey =>
      _apiKey.isNotEmpty &&
      _apiKey != StorageService.defaultApiKeyPlaceholder &&
      _apiKey != 'YOUR_GEMINI_API_KEY_HERE';

  void _loadSettings() {
    _activeProvider = storageService.getActiveProvider();
    _apiKey = storageService.getApiKey(provider: _activeProvider);
    _model = storageService.getModel();
    _temperature = storageService.getTemperature();
    notifyListeners();
  }

  Future<void> setActiveProvider(LlmProviderType provider) async {
    _activeProvider = provider;
    await storageService.setActiveProvider(provider);
    _apiKey = storageService.getApiKey(provider: provider);

    final models = currentProviderModels;
    if (models.isNotEmpty && !models.any((m) => m.id == _model)) {
      _model = models.first.id;
      await storageService.setModel(_model);
    }
    notifyListeners();
  }

  Future<void> setApiKey(String key, {LlmProviderType? provider}) async {
    final targetProvider = provider ?? _activeProvider;
    _apiKey = key;
    await storageService.setApiKey(key, provider: targetProvider);
    notifyListeners();
  }

  Future<void> autoDetectAndSetKey(String key) async {
    final detected = LlmProviderUtils.detectProviderFromKey(key);
    _activeProvider = detected;
    _apiKey = key.trim();
    await storageService.setActiveProvider(detected);
    await storageService.setApiKey(_apiKey, provider: detected);

    final models = currentProviderModels;
    if (models.isNotEmpty && !models.any((m) => m.id == _model)) {
      _model = models.first.id;
      await storageService.setModel(_model);
    }

    notifyListeners();
    await fetchLiveModels();
  }

  Future<void> setModel(String model) async {
    _model = model;
    await storageService.setModel(model);
    notifyListeners();
  }

  Future<void> setTemperature(double temp) async {
    _temperature = temp;
    await storageService.setTemperature(temp);
    notifyListeners();
  }

  Future<void> fetchLiveModels() async {
    if (!hasValidApiKey && _activeProvider != LlmProviderType.ollama) return;
    _isFetchingModels = true;
    notifyListeners();

    try {
      final fetched = await agentService.fetchWorkingModels(_activeProvider, _apiKey);
      if (fetched.isNotEmpty) {
        _availableModels.removeWhere((m) => m.provider == _activeProvider);
        _availableModels.addAll(fetched);
        if (!_availableModels.any((m) => m.id == _model)) {
          _model = fetched.first.id;
          await storageService.setModel(_model);
        }
      }
    } catch (_) {}

    _isFetchingModels = false;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

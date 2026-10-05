import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService storageService;

  static const List<String> availableModels = [
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

  String _apiKey = StorageService.defaultApiKeyPlaceholder;
  String _model = StorageService.defaultModel;
  double _temperature = 0.4;
  bool _isDarkMode = true;

  SettingsProvider({required this.storageService}) {
    _loadSettings();
  }

  String get apiKey => _apiKey;
  String get model => _model;
  double get temperature => _temperature;
  bool get isDarkMode => _isDarkMode;

  bool get hasValidApiKey =>
      _apiKey.isNotEmpty && _apiKey != StorageService.defaultApiKeyPlaceholder;

  void _loadSettings() {
    _apiKey = storageService.getApiKey();
    _model = storageService.getModel();
    _temperature = storageService.getTemperature();
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    await storageService.setApiKey(key);
    notifyListeners();
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

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

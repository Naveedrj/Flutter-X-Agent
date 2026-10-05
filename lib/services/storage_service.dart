import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_session.dart';
import '../models/llm_provider.dart';

class StorageService {
  static const String _keyActiveProvider = 'active_llm_provider';
  static const String _keyModel = 'selected_llm_model';
  static const String _keyTemperature = 'gemini_temperature';
  static const String _keyLastWorkspace = 'last_workspace_path';
  static const String _keySessions = 'chat_sessions_v1';
  static const String _keyActiveSessionId = 'active_session_id';

  static const String defaultApiKeyPlaceholder = 'YOUR_API_KEY_HERE';
  static const String defaultModel = 'qwen-2.5-coder-32b';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  LlmProviderType getActiveProvider() {
    final name = _prefs.getString(_keyActiveProvider);
    if (name != null) {
      return LlmProviderType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => LlmProviderType.groq,
      );
    }
    return LlmProviderType.groq;
  }

  Future<void> setActiveProvider(LlmProviderType type) async {
    await _prefs.setString(_keyActiveProvider, type.name);
  }

  String getApiKey({LlmProviderType? provider}) {
    final p = provider ?? getActiveProvider();
    final key = _prefs.getString('api_key_${p.name}');
    if (key != null && key.isNotEmpty) return key;

    // Fallback for legacy key
    final legacyKey = _prefs.getString('gemini_api_key');
    if (p == LlmProviderType.gemini && legacyKey != null) return legacyKey;

    return defaultApiKeyPlaceholder;
  }

  Future<void> setApiKey(String key, {LlmProviderType? provider}) async {
    final p = provider ?? getActiveProvider();
    await _prefs.setString('api_key_${p.name}', key.trim());
    if (p == LlmProviderType.gemini) {
      await _prefs.setString('gemini_api_key', key.trim());
    }
  }

  String getModel() {
    final m = _prefs.getString(_keyModel);
    if (m == null || m == 'gemini-2.0-flash' || m.isEmpty) {
      return defaultModel;
    }
    return m;
  }

  Future<void> setModel(String model) async {
    await _prefs.setString(_keyModel, model);
  }

  double getTemperature() {
    return _prefs.getDouble(_keyTemperature) ?? 0.4;
  }

  Future<void> setTemperature(double temp) async {
    await _prefs.setDouble(_keyTemperature, temp);
  }

  String? getLastWorkspace() {
    return _prefs.getString(_keyLastWorkspace);
  }

  Future<void> setLastWorkspace(String path) async {
    await _prefs.setString(_keyLastWorkspace, path);
  }

  String? getActiveSessionId() {
    return _prefs.getString(_keyActiveSessionId);
  }

  Future<void> setActiveSessionId(String? id) async {
    if (id == null) {
      await _prefs.remove(_keyActiveSessionId);
    } else {
      await _prefs.setString(_keyActiveSessionId, id);
    }
  }

  List<ChatSession> loadSessions() {
    final raw = _prefs.getString(_keySessions);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((item) => ChatSession.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveSessions(List<ChatSession> sessions) async {
    try {
      final list = sessions.map((s) => s.toJson()).toList();
      final jsonStr = jsonEncode(list);
      await _prefs.setString(_keySessions, jsonStr);
    } catch (_) {}
  }
}

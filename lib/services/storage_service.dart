import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_session.dart';

class StorageService {
  static const String _keyApiKey = 'gemini_api_key';
  static const String _keyModel = 'gemini_model';
  static const String _keyTemperature = 'gemini_temperature';
  static const String _keyLastWorkspace = 'last_workspace_path';
  static const String _keySessions = 'chat_sessions_v1';
  static const String _keyActiveSessionId = 'active_session_id';

  // Default placeholder key as requested by the user
  static const String defaultApiKeyPlaceholder = 'YOUR_GEMINI_API_KEY_HERE';
  static const String defaultModel = 'gemini-3.8-flash';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String getApiKey() {
    return _prefs.getString(_keyApiKey) ?? defaultApiKeyPlaceholder;
  }

  Future<void> setApiKey(String key) async {
    await _prefs.setString(_keyApiKey, key.trim());
  }

  String getModel() {
    final m = _prefs.getString(_keyModel);
    if (m == null || m == 'gemini-2.0-flash' || m == 'gemini-2.0-flash-exp' || m.isEmpty) {
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

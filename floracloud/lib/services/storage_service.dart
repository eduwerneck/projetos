import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';

class StorageService {
  static const String _sessionsKey = 'floracloud_sessions';
  static const String _serverUrlKey = 'floracloud_server_url';

  // Sessions

  static Future<List<FieldSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_sessionsKey) ?? [];
    return jsonList
        .map((s) => FieldSession.fromJsonString(s))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> saveSession(FieldSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await loadSessions();
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }
    await prefs.setStringList(
      _sessionsKey,
      sessions.map((s) => s.toJsonString()).toList(),
    );
  }

  static Future<void> deleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await loadSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    await prefs.setStringList(
      _sessionsKey,
      sessions.map((s) => s.toJsonString()).toList(),
    );
  }

  static Future<FieldSession?> getSession(String sessionId) async {
    final sessions = await loadSessions();
    try {
      return sessions.firstWhere((s) => s.id == sessionId);
    } catch (_) {
      return null;
    }
  }

  // Server URL

  static Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  static Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
  }
}

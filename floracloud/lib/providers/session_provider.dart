import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../services/storage_service.dart';

class SessionProvider extends ChangeNotifier {
  List<FieldSession> _sessions = [];
  bool _isLoading = false;

  List<FieldSession> get sessions => List.unmodifiable(_sessions);
  bool get isLoading => _isLoading;

  int get totalSessions => _sessions.length;
  int get completedSessions =>
      _sessions.where((s) => s.status == SessionStatus.completed).length;
  int get processingSessions =>
      _sessions.where((s) => s.status == SessionStatus.processing).length;

  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();
    _sessions = await StorageService.loadSessions();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addSession(FieldSession session) async {
    await StorageService.saveSession(session);
    _sessions.insert(0, session);
    notifyListeners();
  }

  Future<void> updateSession(FieldSession session) async {
    await StorageService.saveSession(session);
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      _sessions[index] = session;
    }
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    await StorageService.deleteSession(sessionId);
    _sessions.removeWhere((s) => s.id == sessionId);
    notifyListeners();
  }

  FieldSession? getById(String id) {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}

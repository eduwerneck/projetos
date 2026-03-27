import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class SettingsProvider extends ChangeNotifier {
  String _serverUrl = 'http://localhost:8000';
  bool _isConnected = false;
  String? connectionError;

  String get serverUrl => _serverUrl;
  bool get isConnected => _isConnected;

  ApiService get apiService => ApiService(baseUrl: _serverUrl);

  Future<void> load() async {
    final url = await StorageService.getServerUrl();
    if (url != null) _serverUrl = url;
    await checkConnection();
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = url;
    await StorageService.saveServerUrl(url);
    await checkConnection();
    notifyListeners();
  }

  Future<bool> checkConnection() async {
    try {
      _isConnected = await apiService.checkHealth();
      if (_isConnected) connectionError = null;
    } catch (e) {
      _isConnected = false;
      connectionError = e.toString();
    }
    notifyListeners();
    return _isConnected;
  }
}

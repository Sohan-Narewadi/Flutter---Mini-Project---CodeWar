import 'package:shared_preferences/shared_preferences.dart';

/// Small persisted settings: the backend URL (the tunnel address your host
/// shares), the device token issued at registration, and the player's name.
///
/// Reads and writes never throw: if storage is unavailable the values simply
/// live in memory for the session.
class SettingsStore {
  SettingsStore._(this._prefs) {
    _apiUrl = _safeGet('api_url');
    _token = _safeGet('token');
    _playerName = _safeGet('player_name');
  }

  SettingsStore.memory() : _prefs = null;

  final SharedPreferences? _prefs;

  static Future<SettingsStore> open() async {
    try {
      return SettingsStore._(await SharedPreferences.getInstance());
    } catch (_) {
      return SettingsStore.memory();
    }
  }

  String? _apiUrl;
  String? _token;
  String? _playerName;

  String? get apiUrl => _apiUrl;
  set apiUrl(String? v) {
    _apiUrl = _clean(v);
    _safeSet('api_url', _apiUrl);
  }

  String? get token => _token;
  set token(String? v) {
    _token = _clean(v);
    _safeSet('token', _token);
  }

  String? get playerName => _playerName;
  set playerName(String? v) {
    _playerName = _clean(v);
    _safeSet('player_name', _playerName);
  }

  bool get hasToken => _token != null;

  String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  String? _safeGet(String key) {
    try {
      return _prefs?.getString(key);
    } catch (_) {
      return null;
    }
  }

  void _safeSet(String key, String? value) {
    try {
      final p = _prefs;
      if (p == null) return;
      if (value == null) {
        p.remove(key);
      } else {
        p.setString(key, value);
      }
    } catch (_) {}
  }
}

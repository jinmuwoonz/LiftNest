import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService instance = PreferencesService._init();

  static SharedPreferences? _prefs;

  PreferencesService._init();

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Settings
  static const String _keyUseKg = 'useKg';

  Future<bool> getUseKg() async {
    final p = await prefs;
    return p.getBool(_keyUseKg) ?? true;
  }

  Future<void> setUseKg(bool value) async {
    final p = await prefs;
    await p.setBool(_keyUseKg, value);
  }
}

import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiConfig {
  static ApiConfig? _instance;
  String _baseUrl = AppConstants.defaultEmulatorUrl;

  ApiConfig._();

  static ApiConfig get instance {
    _instance ??= ApiConfig._();
    return _instance!;
  }

  String get baseUrl => _baseUrl;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.keyApiBaseUrl);
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = saved.endsWith('/') ? saved.substring(0, saved.length - 1) : saved;
    }
  }

  Future<void> setBaseUrl(String newUrl) async {
    var trimmed = newUrl.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    _baseUrl = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyApiBaseUrl, _baseUrl);
  }
}

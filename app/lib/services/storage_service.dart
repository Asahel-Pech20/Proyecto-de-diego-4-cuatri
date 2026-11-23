import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/user.dart';

class StorageService {
  static StorageService? _instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  StorageService._();

  static StorageService get instance {
    _instance ??= StorageService._();
    return _instance!;
  }

  // Token JWT
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConstants.keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: AppConstants.keyToken);
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: AppConstants.keyToken);
  }

  // Usuario actual
  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUser, jsonEncode(user.toJson()));
  }

  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(AppConstants.keyUser);
    if (data == null) return null;
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return User.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyUser);
  }

  // Última sincronización
  Future<void> saveLastSyncTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyLastSyncTime, time);
  }

  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyLastSyncTime);
  }

  // Limpiar todo (Logout)
  Future<void> clearAll() async {
    await deleteToken();
    await deleteUser();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyLastSyncTime);
  }
}

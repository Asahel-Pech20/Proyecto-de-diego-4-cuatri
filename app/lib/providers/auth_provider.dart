import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null && _currentUser != null;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    // Configurar listener para 401 (token expirado / inválido)
    ApiService.instance.onUnauthorized = () {
      logout();
    };

    try {
      _token = await StorageService.instance.getToken();
      _currentUser = await StorageService.instance.getUser();

      // Si tenemos token guardado, intentamos refrescar datos en segundo plano
      if (_token != null) {
        try {
          final me = await ApiService.instance.getMe();
          _currentUser = me;
          await StorageService.instance.saveUser(me);
        } catch (_) {
          // Si estamos offline mantenemos la sesión con los datos locales
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.instance.login(
        email: email,
        password: password,
      );

      _token = res['token'] as String;
      _currentUser = res['user'] as User;

      await StorageService.instance.saveToken(_token!);
      await StorageService.instance.saveUser(_currentUser!);

      // Sincronización inicial en segundo plano
      SyncService.instance.synchronize();

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Ocurrió un error inesperado al iniciar sesión.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.instance.register(
        name: name,
        email: email,
        password: password,
      );

      _token = res['token'] as String;
      _currentUser = res['user'] as User;

      await StorageService.instance.saveToken(_token!);
      await StorageService.instance.saveUser(_currentUser!);

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Ocurrió un error inesperado al registrar la cuenta.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await StorageService.instance.clearAll();
    await DatabaseService.instance.clearAll();

    _currentUser = null;
    _token = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

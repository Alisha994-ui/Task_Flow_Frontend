import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final SecureStorage _storage = SecureStorage();

  UserModel? _user;

  bool _isLoading = false;
  bool _isAuthenticated = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get role => _user?.role;

  Future<void> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiClient.post(
        '/auth/login/',
        body: {
          'username': username,
          'password': password,
        },
        authenticated: false,
      );

      final accessToken = response['access']?.toString();
      final refreshToken = response['refresh']?.toString();

      if (accessToken == null || refreshToken == null) {
        throw Exception('Login response does not contain JWT tokens.');
      }

      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      await _loadCurrentUser();

      _isAuthenticated = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrentUser() async {
    final response = await ApiClient.get('/auth/me/');

    _user = UserModel.fromJson(response);
  }

  Future<bool> restoreSession() async {
    final accessToken = await _storage.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      _isAuthenticated = false;
      return false;
    }

    try {
      await _loadCurrentUser();

      _isAuthenticated = true;
      notifyListeners();

      return true;
    } catch (_) {
      await _storage.clearTokens();

      _user = null;
      _isAuthenticated = false;

      notifyListeners();

      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearTokens();

    _user = null;
    _isAuthenticated = false;

    notifyListeners();
  }
}
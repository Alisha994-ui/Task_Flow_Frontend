import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final SecureStorage _storage = SecureStorage();

  UserModel? _user;

  bool _isLoading = false;
  bool _isAuthenticated = false;

  bool _restoredFromCache = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get restoredFromCache => _restoredFromCache;
  String? get role => _user?.role;

  static bool _isNetworkError(Object error) {
    return error is NetworkException ||
        error is http.ClientException ||
        error is TimeoutException;
  }

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
        throw Exception(
          'Login response does not contain JWT tokens.',
        );
      }

      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      await _loadCurrentUser();

      _isAuthenticated = true;
      _restoredFromCache = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrentUser() async {
    final response = await ApiClient.get(
      '/auth/me/',
    );

    _user = UserModel.fromJson(response);

    await _storage.saveUserCache(
      jsonEncode(response),
    );
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
      _restoredFromCache = false;

      notifyListeners();

      return true;
    } catch (e) {
      // ----------------------------------------------------------
      // OFFLINE / NETWORK FAILURE
      // ----------------------------------------------------------
      //
      // The server was never reached.
      // Therefore the saved JWT is still considered valid.
      //
      // Restore the last known user instead of logging out.
      if (_isNetworkError(e)) {
        return _restoreFromCacheOrKeepTrying();
      }

      // ----------------------------------------------------------
      // SERVER REJECTED THE SESSION
      // ----------------------------------------------------------
      //
      // Only clear the session when the server was reachable and
      // actively rejected the token.
      await _storage.clearTokens();

      _user = null;
      _isAuthenticated = false;
      _restoredFromCache = false;

      notifyListeners();

      return false;
    }
  }

  Future<bool> _restoreFromCacheOrKeepTrying() async {
    final String? cached = await _storage.getUserCache();

    if (cached == null || cached.isEmpty) {
      _isAuthenticated = false;

      notifyListeners();

      return false;
    }

    try {
      _user = UserModel.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(cached) as Map,
        ),
      );

      _isAuthenticated = true;
      _restoredFromCache = true;

      notifyListeners();

      return true;
    } catch (_) {
      // Do NOT clear tokens here.
      //
      // The cache may be corrupt, but that does not prove that the
      // saved authentication session is invalid.
      _isAuthenticated = false;

      notifyListeners();

      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearTokens();

    _user = null;
    _isAuthenticated = false;
    _restoredFromCache = false;

    notifyListeners();
  }
}

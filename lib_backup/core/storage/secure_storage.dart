import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  /// The last `/auth/me/` response, cached as raw JSON. Lets a start-up
  /// session restore survive with no network at all: there is no server
  /// to ask, but there is no reason to sign the person out either, so
  /// this is what they last looked like.
  static const String _userCacheKey = 'cached_user';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(
      key: _accessTokenKey,
      value: accessToken,
    );

    await _storage.write(
      key: _refreshTokenKey,
      value: refreshToken,
    );
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> saveUserCache(String rawJson) async {
    await _storage.write(key: _userCacheKey, value: rawJson);
  }

  Future<String?> getUserCache() async {
    return await _storage.read(key: _userCacheKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userCacheKey);
  }
}
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the last successful GET response of every endpoint on the phone,
/// so screens can still show real data when there is no internet.
///
/// It lives below the providers (inside `ApiClient`), so no provider or
/// screen has to know about it.
class ApiCache {
  ApiCache._();

  static const String _prefix = 'api_cache:';

  static Future<void> save(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      await prefs.setString('$_prefix$endpoint', jsonEncode(data));
    } catch (_) {
      // Caching is best-effort; never break a real response over it.
    }
  }

  static Future<Map<String, dynamic>?> read(String endpoint) async {
    try {
      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      final String? raw = prefs.getString('$_prefix$endpoint');

      if (raw == null || raw.isEmpty) {
        return null;
      }

      final dynamic decoded = jsonDecode(raw);

      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Call on login and logout so one person's data is never shown to
  /// the next person who signs in on the same phone.
  static Future<void> clear() async {
    try {
      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      for (final String key in prefs.getKeys().toList()) {
        if (key.startsWith(_prefix)) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}
  }
}

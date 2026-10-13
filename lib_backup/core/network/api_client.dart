
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../storage/secure_storage.dart';
import 'api_cache.dart';

class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A request that got no answer in time. Distinct from "offline": the
/// connection may be fine and the server just slow, so it must not flip
/// the offline banner.
class RequestTimeoutException extends NetworkException {
  const RequestTimeoutException()
      : super('The server took too long to answer. Please try again.');
}

class ApiClient {
  ApiClient._();

  /// Server address, chosen at build time (BUG-01):
  ///
  ///   flutter build apk --release \
  ///     --dart-define=API_BASE_URL=https://your-api-domain/api
  ///
  /// A release build has no fallback: it must be given an https:// address,
  /// otherwise [isConfigured] is false and main.dart shows a configuration
  /// error instead of silently talking to a LAN machine over plain HTTP.
  /// Debug/profile builds fall back to the local dev server.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? '' : 'http://192.168.18.180:8000/api',
  );

  /// False for a release build without a secure (https) server address.
  static bool get isConfigured {
    if (baseUrl.isEmpty) {
      return false;
    }

    return !kReleaseMode || baseUrl.startsWith('https://');
  }
  static const String refreshEndpoint = '/auth/refresh/';

  static final SecureStorage _storage = SecureStorage();

  static Future<bool>? _refreshing;

  static bool sessionExpired = false;

  // Called when an API request succeeds.
  static VoidCallback? onConnectionRestored;

  /// Called when the server has really rejected the saved session (the
  /// refresh token itself is invalid or expired). Never fires for a
  /// network failure - those keep the person signed in.
  static Future<void> Function()? onSessionExpired;

  /// True while the last request failed because there is no connection.
  /// The offline banner and the empty/error views listen to this.
  static final ValueNotifier<bool> offline = ValueNotifier<bool>(false);

  /// Whether the phone itself has a network (Wi-Fi / data). Kept up to date
  /// by `ConnectivityWatcher`. Lets us tell "no internet" apart from
  /// "internet works but the server cannot be reached".
  static final ValueNotifier<bool> deviceOnline = ValueNotifier<bool>(true);

  static const String serverUnreachableMessage =
      "Can't reach the server. Check your internet connection and try "
      'again.';

  static String get _failureMessage =>
      deviceOnline.value ? serverUnreachableMessage : offlineWriteMessage;

  static const String offlineWriteMessage =
      "You're offline. Connect to the internet and try again.";

  static const String offlineNoDataMessage =
      "You're offline and this page has no saved data yet.";

  static void _markOnline() {
    offline.value = false;
    onConnectionRestored?.call();
  }

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    bool authenticated = true,
  }) async {
    try {
      final response = await _send(
        (headers) => http.get(
          Uri.parse('$baseUrl$endpoint'),
          headers: headers,
        ),
        authenticated,
        timeout: const Duration(seconds: 12),
      );

      final Map<String, dynamic> data =
          _handleResponse(response, authenticated: authenticated);

      await ApiCache.save(endpoint, data);

      return data;
    } on NetworkException catch (e) {
      // No connection (or no answer in time): fall back to the last data
      // we saw for this page.
      final Map<String, dynamic>? cached =
          await ApiCache.read(endpoint);

      if (cached != null) {
        return cached;
      }

      if (e is RequestTimeoutException) {
        rethrow;
      }

      throw NetworkException(
        deviceOnline.value ? serverUnreachableMessage : offlineNoDataMessage,
      );
    }
  }

  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      (headers) => http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      authenticated,
    );

    return _handleResponse(response, authenticated: authenticated);
  }

  static Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      (headers) => http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      authenticated,
    );

    return _handleResponse(response, authenticated: authenticated);
  }

  static Future<void> delete(
    String endpoint, {
    bool authenticated = true,
  }) async {
    final response = await _send(
      (headers) => http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      ),
      authenticated,
    );

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      _markOnline();
      return;
    }

    dynamic decoded;

    try {
      if (response.body.isNotEmpty) {
        decoded = jsonDecode(response.body);
      }
    } catch (_) {
      decoded = null;
    }

    if (decoded is Map<String, dynamic>) {
      throw Exception(
        decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            'Delete failed (${response.statusCode})',
      );
    }

    throw Exception(
      'Delete failed (${response.statusCode})',
    );
  }

  static Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    required String filePath,
    String fileField = 'file',
    Map<String, String> fields = const <String, String>{},
    bool authenticated = true,
  }) async {
    Future<http.Response> attempt(
      Map<String, String> headers,
    ) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$endpoint'),
      );

      final multipartHeaders = Map<String, String>.from(headers)
        ..remove('Content-Type');

      request.headers.addAll(multipartHeaders);
      request.fields.addAll(fields);

      request.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          filePath,
        ),
      );

      final streamed = await request.send();

      return http.Response.fromStream(streamed);
    }

    final response = await _send(attempt, authenticated);

    return _handleResponse(response);
  }

  static Future<http.Response> _send(
    Future<http.Response> Function(
      Map<String, String> headers,
    ) attempt,
    bool authenticated, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final http.Response response;

    try {
      response = await attempt(
        await _headers(authenticated),
      ).timeout(timeout);
    } catch (e) {
      throw _friendlyNetworkError(e);
    }

    if (response.statusCode != 401 || !authenticated) {
      return response;
    }

    final bool refreshed = await _refreshAccessToken();

    if (!refreshed) {
      if (!sessionExpired) {
        offline.value = true;
        throw NetworkException(_failureMessage);
      }

      return response;
    }

    try {
      return await attempt(
        await _headers(authenticated),
      ).timeout(timeout);
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  static Exception _friendlyNetworkError(Object error) {
    debugPrint('API NETWORK ERROR: $error');

    if (error is NetworkException) {
      return error;
    }

    if (error is TimeoutException) {
      return const RequestTimeoutException();
    }

    if (error is SocketException ||
        error is http.ClientException ||
        error is HandshakeException) {
      offline.value = true;
      return NetworkException(_failureMessage);
    }

    return error is Exception
        ? error
        : Exception(error.toString());
  }

  static Future<bool> _refreshAccessToken() async {
    final inFlight = _refreshing;

    if (inFlight != null) {
      return inFlight;
    }

    final completer = Completer<bool>();
    _refreshing = completer.future;

    try {
      final refreshToken = await _storage.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        sessionExpired = true;
        completer.complete(false);
        return false;
      }

      final http.Response response;

      try {
        response = await http
            .post(
              Uri.parse('$baseUrl$refreshEndpoint'),
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'refresh': refreshToken,
              }),
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        sessionExpired = false;
        completer.complete(false);
        return false;
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        final bool rejectedSession =
            response.statusCode == 401 ||
            response.statusCode == 403;

        if (rejectedSession) {
          await _storage.clearTokens();
          await ApiCache.clear();
        }

        sessionExpired = rejectedSession;
        completer.complete(false);
        return false;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        sessionExpired = true;
        completer.complete(false);
        return false;
      }

      final access = decoded['access']?.toString();

      if (access == null || access.isEmpty) {
        sessionExpired = true;
        completer.complete(false);
        return false;
      }

      final newRefresh =
          decoded['refresh']?.toString() ?? refreshToken;

      await _storage.saveTokens(
        accessToken: access,
        refreshToken: newRefresh,
      );

      sessionExpired = false;
      completer.complete(true);
      return true;
    } catch (_) {
      sessionExpired = false;
      completer.complete(false);
      return false;
    } finally {
      _refreshing = null;
    }
  }

  static Future<Map<String, String>> _headers(
    bool authenticated,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authenticated) {
      final token = await _storage.getAccessToken();

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static String get serverRoot {
    if (baseUrl.endsWith('/api')) {
      return baseUrl.substring(0, baseUrl.length - 4);
    }

    return baseUrl;
  }

  static String absoluteUrl(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') ||
        pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }

    if (pathOrUrl.startsWith('/')) {
      return '$serverRoot$pathOrUrl';
    }

    return '$serverRoot/$pathOrUrl';
  }

  static Map<String, dynamic> _handleResponse(
    http.Response response, {
    bool authenticated = true,
  }) {
    dynamic decoded;

    try {
      if (response.body.isNotEmpty) {
        decoded = jsonDecode(response.body);
      } else {
        decoded = <String, dynamic>{};
      }
    } catch (_) {
      decoded = {'detail': response.body};
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      _markOnline();

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {'data': decoded};
    }

    // A 401 on an unauthenticated call (the sign-in itself) means wrong
    // credentials, not an ended session - pass the server's own reason on
    // instead of "session ended", and never trigger the sign-out handler.
    if (response.statusCode == 401 && !authenticated) {
      throw Exception(
        decoded is Map<String, dynamic> && decoded['detail'] != null
            ? decoded['detail'].toString()
            : 'Incorrect username or password.',
      );
    }

    if (response.statusCode == 401) {
      if (sessionExpired) {
        onSessionExpired?.call();
      }

      throw Exception(
        'Your session has ended. Please sign in again.',
      );
    }

    if (decoded is Map<String, dynamic>) {
      throw Exception(
        decoded['detail']?.toString() ??
            decoded['message']?.toString() ??
            _extractValidationError(decoded) ??
            'Request failed (${response.statusCode})',
      );
    }

    throw Exception(
      'Request failed (${response.statusCode})',
    );
  }

  static String? _extractValidationError(
    Map<String, dynamic> data,
  ) {
    final errors = <String>[];

    for (final entry in data.entries) {
      final value = entry.value;

      if (value is List && value.isNotEmpty) {
        errors.add('${entry.key}: ${value.first}');
      } else if (value is String) {
        errors.add('${entry.key}: $value');
      }
    }

    if (errors.isEmpty) {
      return null;
    }

    return errors.join('\n');
  }
}

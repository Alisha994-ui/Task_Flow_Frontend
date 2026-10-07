import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../storage/secure_storage.dart';

class NetworkException implements Exception {
  const NetworkException(
    this.message,
  );

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  // ============================================================
  // BASE URL
  // ============================================================

  static const String baseUrl =
      'http://192.168.100.4:8000/api';

  static const String refreshEndpoint = '/auth/refresh/';

  static final SecureStorage _storage = SecureStorage();

  static Future<bool>? _refreshing;

  static bool sessionExpired = false;

  // ============================================================
  // GET
  // ============================================================

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    bool authenticated = true,
  }) async {
    final response = await _send(
      (headers) => http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      ),
      authenticated,
    );

    return _handleResponse(response);
  }

  // ============================================================
  // POST
  // ============================================================

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

    return _handleResponse(response);
  }

  // ============================================================
  // PATCH
  // ============================================================

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

    return _handleResponse(response);
  }

  // ============================================================
  // DELETE
  // ============================================================

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

  // ============================================================
  // MULTIPART POST
  // ============================================================

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

    final response = await _send(
      attempt,
      authenticated,
    );

    return _handleResponse(response);
  }

  // ============================================================
  // SENDING, WITH ONE SILENT RETRY
  // ============================================================

  static Future<http.Response> _send(
    Future<http.Response> Function(
      Map<String, String> headers,
    ) attempt,
    bool authenticated,
  ) async {
    final http.Response response;

    try {
      response = await attempt(
        await _headers(authenticated),
      );
    } catch (e) {
      throw _friendlyNetworkError(e);
    }

    if (response.statusCode != 401 || !authenticated) {
      return response;
    }

    final bool refreshed = await _refreshAccessToken();

    if (!refreshed) {
      // Refresh failed because the network disappeared.
      // The 401 must NOT be treated as an invalid session in
      // that case.
      if (!sessionExpired) {
        throw const NetworkException(
          "Can't reach the server. Check your connection and try again.",
        );
      }

      return response;
    }

    try {
      return await attempt(
        await _headers(authenticated),
      );
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  // ============================================================
  // NETWORK ERROR
  // ============================================================

  static Exception _friendlyNetworkError(Object error) {
    debugPrint('API NETWORK ERROR: $error');

    if (error is NetworkException) {
      return error;
    }

    if (error is SocketException ||
        error is http.ClientException ||
        error is HandshakeException ||
        error is TimeoutException) {
      return NetworkException(
        "Network error: $error",
      );
    }

    return error is Exception
        ? error
        : Exception(error.toString());
  }

  // ============================================================
  // REFRESH ACCESS TOKEN
  // ============================================================

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
      } catch (e) {
        // IMPORTANT:
        // Network failure is NOT token expiration.
        sessionExpired = false;
        completer.complete(false);

        return false;
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        await _storage.clearTokens();

        sessionExpired = true;
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
      // Unexpected refresh failure must not automatically
      // destroy the saved session.
      sessionExpired = false;
      completer.complete(false);

      return false;
    } finally {
      _refreshing = null;
    }
  }

  // ============================================================
  // HEADERS
  // ============================================================

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

  // ============================================================
  // MEDIA URLS
  // ============================================================

  static String get serverRoot {
    if (baseUrl.endsWith('/api')) {
      return baseUrl.substring(
        0,
        baseUrl.length - 4,
      );
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

  // ============================================================
  // RESPONSE HANDLER
  // ============================================================

  static Map<String, dynamic> _handleResponse(
    http.Response response,
  ) {
    dynamic decoded;

    try {
      if (response.body.isNotEmpty) {
        decoded = jsonDecode(response.body);
      } else {
        decoded = <String, dynamic>{};
      }
    } catch (_) {
      decoded = {
        'detail': response.body,
      };
    }

    // SUCCESS

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'data': decoded,
      };
    }

    // 401 means the server actively rejected the session.
    if (response.statusCode == 401) {
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

  // ============================================================
  // VALIDATION ERROR HANDLER
  // ============================================================

  static String? _extractValidationError(
    Map<String, dynamic> data,
  ) {
    final errors = <String>[];

    for (final entry in data.entries) {
      final value = entry.value;

      if (value is List && value.isNotEmpty) {
        errors.add(
          '${entry.key}: ${value.first}',
        );
      } else if (value is String) {
        errors.add(
          '${entry.key}: $value',
        );
      }
    }

    if (errors.isEmpty) {
      return null;
    }

    return errors.join('\n');
  }
}
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../storage/secure_storage.dart';

class ApiClient {
  ApiClient._();

  // ============================================================
  // BASE URL
  // ============================================================

  static const String baseUrl =
      'http://192.168.100.4:8000/api';

  static final SecureStorage _storage =
      SecureStorage();

  // ============================================================
  // GET
  // ============================================================

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    bool authenticated = true,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(authenticated),
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
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(authenticated),
      body: body == null ? null : jsonEncode(body),
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
    final response = await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(authenticated),
      body: body == null ? null : jsonEncode(body),
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
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(authenticated),
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
  // MULTIPART POST (file upload)
  // ============================================================

  static Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    required String filePath,
    String fileField = 'file',
    Map<String, String> fields = const <String, String>{},
    bool authenticated = true,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$endpoint'),
    );

    final headers = await _headers(authenticated);

    // MultipartRequest writes its own Content-Type with a boundary,
    // so the JSON one has to go.
    headers.remove('Content-Type');
    request.headers.addAll(headers);

    request.fields.addAll(fields);

    request.files.add(
      await http.MultipartFile.fromPath(
        fileField,
        filePath,
      ),
    );

    final streamed = await request.send();

    final response =
        await http.Response.fromStream(streamed);

    return _handleResponse(response);
  }

  // ============================================================
  // MEDIA URLS
  // ============================================================

  /// The server without the trailing /api, so uploaded files resolve.
  ///   baseUrl     http://192.168.100.4:8000/api
  ///   serverRoot  http://192.168.100.4:8000
  static String get serverRoot {
    if (baseUrl.endsWith('/api')) {
      return baseUrl.substring(
        0,
        baseUrl.length - 4,
      );
    }

    return baseUrl;
  }

  /// Django may return a full URL or a path such as
  /// /media/task_attachments/spec.pdf - this makes both openable.
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
      final token =
          await _storage.getAccessToken();

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] =
            'Bearer $token';
      }
    }

    return headers;
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

    // ----------------------------------------------------------
    // SUCCESS
    // ----------------------------------------------------------

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {
        'data': decoded,
      };
    }

    // ----------------------------------------------------------
    // ERROR
    // ----------------------------------------------------------

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
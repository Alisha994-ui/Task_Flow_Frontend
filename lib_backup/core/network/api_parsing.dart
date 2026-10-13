/// DRF returns two shapes in this project:
///
/// * ViewSet list endpoints are paginated: `{count, next, previous, results}`
/// * `@action` endpoints return a bare JSON array
///
/// These helpers accept either so one parser works for both.
List<Map<String, dynamic>> extractResults(dynamic response) {
  if (response is List) {
    return response
        .whereType<dynamic>()
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  if (response is Map) {
    // Paginated list endpoints.
    final dynamic results = response['results'];

    if (results is List) {
      return results
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    // ApiClient wraps a bare JSON array as {'data': [...]}, which is what
    // the @action endpoints return.
    final dynamic data = response['data'];

    if (data is List) {
      return data
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
  }

  return <Map<String, dynamic>>[];
}

/// Non-null when another page of results exists.
String? nextPageUrl(dynamic response) {
  if (response is Map) {
    final dynamic next = response['next'];

    if (next is String && next.isNotEmpty) {
      return next;
    }
  }

  return null;
}

/// Builds `?a=1&b=2`, skipping null and empty values.
String buildQuery(Map<String, dynamic> params) {
  final List<String> parts = <String>[];

  params.forEach((String key, dynamic value) {
    if (value == null) {
      return;
    }

    final String text = value.toString();

    if (text.isEmpty) {
      return;
    }

    parts.add('$key=${Uri.encodeQueryComponent(text)}');
  });

  if (parts.isEmpty) {
    return '';
  }

  return '?${parts.join('&')}';
}

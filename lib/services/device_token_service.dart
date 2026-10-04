import 'dart:io' show Platform;

import '../core/network/api_client.dart';

/// Hands the phone's Firebase token to Django so it knows where to send
/// a push. One row per device per person.
class DeviceTokenService {
  static String get _platform {
    if (Platform.isAndroid) {
      return 'android';
    }

    if (Platform.isIOS) {
      return 'ios';
    }

    return 'other';
  }

  static Future<void> register(String token) async {
    await ApiClient.post(
      '/device-tokens/',
      body: <String, dynamic>{
        'token': token,
        'platform': _platform,
      },
    );
  }

  /// Called on logout. The backend deletes by token, not by id, because
  /// the app never learns the row's id.
  static Future<void> unregister(String token) async {
    await ApiClient.post(
      '/device-tokens/remove/',
      body: <String, dynamic>{'token': token},
    );
  }
}

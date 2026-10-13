import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../services/app_config_service.dart';
import 'api_client.dart';

/// Flips the offline banner the moment Wi-Fi / mobile data is switched
/// off, instead of waiting for the next request to fail. When a network
/// comes back it makes one small request to confirm the internet really
/// works (Wi-Fi can be connected with no internet).
class ConnectivityWatcher {
  ConnectivityWatcher._();

  static StreamSubscription<dynamic>? _sub;

  static void start() {
    _sub?.cancel();

    final Connectivity connectivity = Connectivity();

    // Works with both connectivity_plus API shapes (single value / list).
    bool hasNetwork(dynamic result) {
      final List<dynamic> list = result is List ? result : <dynamic>[result];
      return list.any((dynamic r) => r != ConnectivityResult.none);
    }

    connectivity.checkConnectivity().then((dynamic result) {
      ApiClient.deviceOnline.value = hasNetwork(result);

      if (!hasNetwork(result)) {
        ApiClient.offline.value = true;
      }
    });

    _sub = connectivity.onConnectivityChanged.listen((dynamic result) async {
      ApiClient.deviceOnline.value = hasNetwork(result);

      if (!hasNetwork(result)) {
        ApiClient.offline.value = true;
        return;
      }

      try {
        await AppConfigService.load();
      } catch (_) {
        // Still unreachable; the failed request keeps the flag on.
      }
    });
  }
}

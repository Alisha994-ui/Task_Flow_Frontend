import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

/// Drop-in replacement for [RefreshIndicator] used on every screen.
///
/// Offline, a refresh fails in a split second and is then answered from
/// saved data, so by default nothing visibly happens. This keeps the
/// spinner up briefly and then says clearly that the data is saved data.
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final Stopwatch watch = Stopwatch()..start();

        await onRefresh();

        const int minMs = 700;
        if (watch.elapsedMilliseconds < minMs) {
          await Future<void>.delayed(
            Duration(milliseconds: minMs - watch.elapsedMilliseconds),
          );
        }

        if (!context.mounted || !ApiClient.offline.value) {
          return;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                "You're offline. Could not refresh - showing saved data.",
              ),
            ),
          );
      },
      child: child,
    );
  }
}

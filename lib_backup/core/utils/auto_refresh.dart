import 'dart:async';

import 'package:flutter/widgets.dart';

/// Keeps a screen's data current without anybody pressing anything.
///
/// Two triggers, because a timer alone is not enough: a phone that has
/// been in a pocket for an hour needs fresh data the moment it is
/// looked at, not 45 seconds later.
///
///   * every [interval] while the screen is open and in front
///   * the moment the app comes back from the background
///
/// The timer is paused while the app is backgrounded. Polling a server
/// from a screen nobody is looking at is just battery and data.
///
/// Usage, from a State:
///
///     late final AutoRefresher _auto;
///
///     void initState() {
///       super.initState();
///       _auto = AutoRefresher(onRefresh: _loadAll)..start();
///     }
///
///     void dispose() {
///       _auto.dispose();
///       super.dispose();
///     }
class AutoRefresher with WidgetsBindingObserver {
  AutoRefresher({
    required this.onRefresh,
    this.interval = const Duration(seconds: 45),
  });

  /// Should load quietly - no spinners, no clearing what is on screen.
  final Future<void> Function() onRefresh;

  final Duration interval;

  Timer? _timer;
  bool _running = false;

  /// True while a refresh is in flight, so a slow network cannot stack
  /// requests on top of each other.
  bool _busy = false;

  void start() {
    if (_running) {
      return;
    }

    _running = true;
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void dispose() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (_busy) {
      return;
    }

    _busy = true;

    try {
      await onRefresh();
    } catch (_) {
      // A failed poll is not worth reporting - the next one is 45
      // seconds away, and the screen still holds the last good data.
    } finally {
      _busy = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _startTimer();
      _tick();

      return;
    }

    // paused, inactive, hidden, detached - stop polling.
    _timer?.cancel();
    _timer = null;
  }
}

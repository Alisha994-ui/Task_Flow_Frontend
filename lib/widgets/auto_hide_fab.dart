import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';

import '../providers/coach_provider.dart';
/// Whether the floating action button is currently shown.
class FabVisibility extends ValueNotifier<bool> {
  FabVisibility() : super(true);

  /// Hide while the person scrolls down a list, show again as soon as they
  /// scroll back up or reach the top. Horizontal scrolling (the task
  /// board's columns) is ignored.
  bool handleScroll(UserScrollNotification notification) {
    final ScrollMetrics metrics = notification.metrics;

    if (metrics.axis != Axis.vertical) {
      return false;
    }

    if (metrics.pixels <= metrics.minScrollExtent) {
      value = true;
    } else if (notification.direction == ScrollDirection.reverse) {
      value = false;
    } else if (notification.direction == ScrollDirection.forward) {
      value = true;
    }

    return false;
  }

  void show() => value = true;
}

/// Wraps a screen so its FAB slides out of the way while a list scrolls
/// under it - the button never sits on top of card text (BUG-12).
///
/// ```dart
/// return FabScrollHost(
///   builder: (_, fab) => Scaffold(
///     body: ...,
///     floatingActionButton: AutoHideFab.wrap(fab, FloatingActionButton(...)),
///   ),
/// );
/// ```
class FabScrollHost extends StatefulWidget {
  const FabScrollHost({super.key, required this.builder});

  final Widget Function(BuildContext context, FabVisibility fab) builder;

  @override
  State<FabScrollHost> createState() => _FabScrollHostState();
}

class _FabScrollHostState extends State<FabScrollHost> {
  final FabVisibility _fab = FabVisibility();

  @override
  void dispose() {
    _fab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<UserScrollNotification>(
      onNotification: _fab.handleScroll,
      child: widget.builder(context, _fab),
    );
  }
}

class AutoHideFab extends StatefulWidget {
  const AutoHideFab({
    super.key,
    required this.visibility,
    required this.child,
    this.resetKey,
  });

  /// Keeps `null` as `null`, so screens that show no FAB on some tabs
  /// still get no FAB there.
  static Widget? wrap(
    FabVisibility visibility,
    Widget? fab, {
    Object? resetKey,
  }) {
    if (fab == null) {
      return null;
    }

    return AutoHideFab(
      visibility: visibility,
      resetKey: resetKey,
      child: fab,
    );
  }

  final FabVisibility visibility;
  final Widget child;

  /// When this changes (e.g. the selected tab), the button comes back.
  final Object? resetKey;

  @override
  State<AutoHideFab> createState() => _AutoHideFabState();
}

class _AutoHideFabState extends State<AutoHideFab> {
  @override
  void initState() {
    super.initState();
    // A FAB that has just appeared (new tab) starts visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.visibility.show();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AutoHideFab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.resetKey != widget.resetKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.visibility.show();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // A walkthrough step pointing at this button keeps it on screen.
    // Hidden by a scroll, it slid off the bottom - and the spotlight
    // went with it, lighting up empty space below the screen.
    final bool coachNeedsIt = context.select<CoachProvider, bool>(
      (CoachProvider coach) =>
          coach.isActive && (coach.target?.endsWith('_fab') ?? false),
    );

    return ValueListenableBuilder<bool>(
      valueListenable: widget.visibility,
      child: widget.child,
      builder: (BuildContext context, bool shown, Widget? child) {
        final bool visible = shown || coachNeedsIt;

        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 2),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

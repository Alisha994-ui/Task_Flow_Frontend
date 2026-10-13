import 'package:flutter/material.dart';

import '../../providers/coach_provider.dart';

/// Moves a walkthrough along when the person actually does the thing.
///
/// A step that says "tap the + button" should not also need a tap on
/// Next. Opening a screen is something the app can see, so it advances
/// on its own; the steps inside a form - type this, pick that - still
/// need the button, because nothing observable happens between them.
///
/// Only full page routes count. Dialogs, bottom sheets and menus push
/// routes too, and advancing on those would race ahead of the person.
class CoachObserver extends NavigatorObserver {
  CoachObserver(this.coach);

  final CoachProvider coach;

  bool _counts(Route<dynamic>? route) {
    return route is PageRoute && route.settings.name != '/';
  }

  /// A guard against moving twice for one action.
  ///
  /// Opening a form pushes a route; some screens then push another
  /// straight away, and saving pops back through all of them. Without
  /// this the walkthrough runs off the end while the person is still
  /// on the first field.
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void _advance() {
    final DateTime now = DateTime.now();

    if (now.difference(_last) < const Duration(milliseconds: 700)) {
      return;
    }

    _last = now;
    coach.next();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (coach.isActive && _counts(route)) {
      _advance();
    }

    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Only count coming back from a screen the walkthrough sent them
    // to. A pop while the step still points at something on the form -
    // a date picker closing, say - is not progress.
    if (coach.isActive && _counts(route) && coach.target == null) {
      _advance();
    }

    super.didPop(route, previousRoute);
  }
}

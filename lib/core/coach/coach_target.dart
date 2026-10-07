import 'package:flutter/material.dart';

/// Names the walkthrough can point at.
///
/// A step says "type the team name" and carries [TARGET:team_name].
/// For the bubble to sit next to that field, something has to know
/// where the field is on screen - so each one wraps itself in a
/// [CoachTarget] and registers under a name.
///
/// The names are a contract with guide.py on the server: if a name is
/// listed there it must exist here, or the step quietly falls back to
/// a plain banner.
class CoachTargets {
  const CoachTargets._();

  static final Map<String, GlobalKey> _keys = <String, GlobalKey>{};

  /// Always a fresh key, and the newest one wins.
  ///
  /// Reusing a key looked tidier and was wrong. Flutter builds the new
  /// screen before disposing the old one, so a second visit to a form
  /// got handed the previous key - and then the old widget's dispose
  /// removed that entry, leaving the live field registered under
  /// nothing. The walkthrough worked the first time and fell back to a
  /// plain strip ever after.
  static GlobalKey register(String name) {
    final GlobalKey key = GlobalKey(debugLabel: name);
    _keys[name] = key;

    return key;
  }

  /// Only clears the entry if it is still ours - the screen being
  /// disposed may have already been replaced by a newer one.
  static void unregister(String name, GlobalKey key) {
    if (identical(_keys[name], key)) {
      _keys.remove(name);
    }
  }

  /// Where [name] is on screen right now, or null when it is not built -
  /// the person may be on a different tab, or the form is not open yet.
  static Rect? rectOf(String name) {
    final GlobalKey? key = _keys[name];
    final BuildContext? context = key?.currentContext;

    if (context == null || !context.mounted) {
      return null;
    }

    final RenderObject? object = context.findRenderObject();

    if (object is! RenderBox || !object.hasSize) {
      return null;
    }

    final Offset topLeft = object.localToGlobal(Offset.zero);

    return topLeft & object.size;
  }
}

/// Wraps anything the walkthrough may point at.
///
///     CoachTarget(
///       name: 'team_name',
///       child: TextFormField(...),
///     )
///
/// Costs nothing when no walkthrough is running - it only holds a key.
class CoachTarget extends StatefulWidget {
  const CoachTarget({
    super.key,
    required this.name,
    required this.child,
  });

  final String name;
  final Widget child;

  @override
  State<CoachTarget> createState() => _CoachTargetState();
}

class _CoachTargetState extends State<CoachTarget> {
  late GlobalKey _key;

  @override
  void initState() {
    super.initState();
    _key = CoachTargets.register(widget.name);
  }

  @override
  void didUpdateWidget(CoachTarget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.name != widget.name) {
      CoachTargets.unregister(oldWidget.name, _key);
      _key = CoachTargets.register(widget.name);
    }
  }

  @override
  void dispose() {
    CoachTargets.unregister(widget.name, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

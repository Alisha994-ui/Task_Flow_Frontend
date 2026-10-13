import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/coach/coach_target.dart';
import '../providers/coach_provider.dart';

/// Draws the walkthrough over the app: the control lit up, everything
/// else dimmed, and a bubble pointing at it.
///
/// The dim layer ignores taps, so the control underneath still works -
/// the point is for somebody to press the real button, not a copy of
/// it. Only the bubble itself takes taps.
///
/// When the step names no control, or that control is not on screen
/// yet, it falls back to a plain strip at the top. Better a visible
/// instruction in the wrong shape than none.
class CoachOverlay extends StatefulWidget {
  const CoachOverlay({super.key});

  @override
  State<CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<CoachOverlay> {
  /// Where the current target sits. Polled rather than computed once:
  /// the control moves when a list scrolls, a keyboard opens, or a form
  /// finishes animating in - and the step often arrives before the
  /// screen it points at has settled.
  Rect? _rect;
  String? _for;

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// One timer, ever. The earlier version re-scheduled itself from
  /// build, which spawned a new chain on every rebuild - and those
  /// chains fought each other, so the rect was often stale and the
  /// bubble fell back to the plain strip.
  void _ensurePolling(bool active) {
    if (!active) {
      _timer?.cancel();
      _timer = null;

      return;
    }

    if (_timer != null) {
      return;
    }

    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) => _measure());
  }

  void _measure() {
    if (!mounted) {
      return;
    }

    final CoachProvider coach = context.read<CoachProvider>();

    if (!coach.isActive) {
      _ensurePolling(false);

      return;
    }

    final String? target = coach.target;
    final Rect? rect = target == null ? null : CoachTargets.rectOf(target);

    if (rect != _rect || target != _for) {
      setState(() {
        _rect = rect;
        _for = target;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final CoachProvider coach = context.watch<CoachProvider>();

    _ensurePolling(coach.isActive);

    if (!coach.isActive) {
      return const SizedBox.shrink();
    }

    // Measure as soon as a new step arrives rather than waiting up to
    // 60ms for the next tick - otherwise every step flashes the strip
    // before the spotlight appears.
    if (coach.target != _for) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }

    final Rect? rect = (coach.target != null && coach.target == _for)
        ? _rect
        : null;

    // Some steps are not about one control - "find your task in this
    // list", "open the Members tab". There is nothing to light up, so
    // the bubble sits at the bottom on its own dim layer. Same card,
    // same buttons: one look throughout.
    if (rect == null) {
      return _Floating(coach: coach);
    }

    return _Spotlight(coach: coach, rect: rect);
  }
}

class _Spotlight extends StatelessWidget {
  const _Spotlight({required this.coach, required this.rect});

  final CoachProvider coach;
  final Rect rect;

  static const double _pad = 6;
  static const double _arrow = 9;
  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;
    final EdgeInsets safe = MediaQuery.of(context).padding;

    final RRect hole = RRect.fromRectAndRadius(
      rect.inflate(_pad),
      const Radius.circular(12),
    );

    // Below the target if there is room, otherwise above it.
    final double roomBelow = screen.height - rect.bottom - safe.bottom;
    final bool below = roomBelow > 190;

    return Stack(
      children: <Widget>[
        // The dim layer. IgnorePointer is the whole trick: the real
        // button stays pressable, which is what moves the walkthrough
        // on.
        IgnorePointer(
          child: CustomPaint(
            size: screen,
            painter: _ScrimPainter(hole: hole),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: below ? rect.bottom + _pad + _gap : null,
          bottom: below
              ? null
              : screen.height - rect.top + _pad + _gap,
          child: _Bubble(
            coach: coach,
            pointerX: rect.center.dx.clamp(32.0, screen.width - 32.0),
            pointsUp: below,
            arrow: _arrow,
          ),
        ),
      ],
    );
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.hole});

  final RRect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final Path full = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path cut = Path()..addRRect(hole);

    canvas.drawPath(
      Path.combine(PathOperation.difference, full, cut),
      Paint()..color = const Color(0xCC0B1220),
    );

    // A ring, so the lit control reads as chosen rather than as a gap
    // in the dimming.
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF14B8A6),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) => oldDelegate.hole != hole;
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.coach,
    required this.pointerX,
    required this.pointsUp,
    required this.arrow,
  });

  final CoachProvider coach;
  final double pointerX;
  final bool pointsUp;
  final double arrow;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget card = Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    coach.title.isEmpty
                        ? '${coach.index + 1} of ${coach.total}'
                        : '${coach.title} · ${coach.index + 1}/${coach.total}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                _IconTap(
                  icon: Icons.close,
                  color: theme.colorScheme.outline,
                  onTap: coach.stop,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                coach.current,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                ...List<Widget>.generate(
                  coach.total,
                  (int i) => Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= coach.index
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const Spacer(),
                if (!coach.isFirst)
                  _IconTap(
                    icon: Icons.arrow_back,
                    color: theme.colorScheme.outline,
                    onTap: coach.previous,
                  ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: coach.isLast ? coach.stop : coach.next,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                  ),
                  child: Text(coach.isLast ? 'Done' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // arrow == 0 means there is no target, so no tip is drawn.
    final Widget tip = arrow == 0
        ? const SizedBox.shrink()
        : CustomPaint(
            size: Size(arrow * 2, arrow),
            painter: _ArrowPainter(
              color: theme.colorScheme.surface,
              pointsUp: pointsUp,
            ),
          );

    // The arrow sits under the bubble's left edge, nudged across to sit
    // beneath the thing it points at.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (pointsUp)
          Padding(
            padding: EdgeInsets.only(left: (pointerX - 12 - arrow).clamp(8, 9999)),
            child: tip,
          ),
        card,
        if (!pointsUp)
          Padding(
            padding: EdgeInsets.only(left: (pointerX - 12 - arrow).clamp(8, 9999)),
            child: tip,
          ),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.color, required this.pointsUp});

  final Color color;
  final bool pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path();

    if (pointsUp) {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
    }

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointsUp != pointsUp;
}

/// The bubble with no target to sit beside.
///
/// Still dims the screen, so the walkthrough reads as one thing rather
/// than two - the earlier version used a pale strip at the top and it
/// looked like a different feature had appeared.
class _Floating extends StatelessWidget {
  const _Floating({required this.coach});

  final CoachProvider coach;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const IgnorePointer(
          child: ColoredBox(
            color: Color(0x990B1220),
            child: SizedBox.expand(),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).padding.bottom + 20,
          child: _Bubble(
            coach: coach,
            pointerX: 0,
            pointsUp: false,
            arrow: 0,
          ),
        ),
      ],
    );
  }
}

class _IconTap extends StatelessWidget {
  const _IconTap({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }
}

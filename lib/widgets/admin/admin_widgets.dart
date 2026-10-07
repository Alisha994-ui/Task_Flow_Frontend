import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

/// Shared building blocks. Everything here follows AppTheme, so changing
/// the palette there changes these too.

/// Wraps a form screen so the back gesture/button behaves the same way
/// everywhere: with the keyboard open, the first Back only dismisses it
/// (never the screen and the keyboard at once); with it closed, Back
/// leaves immediately on a clean form or asks "Discard changes?" first
/// on a dirty one - instead of silently losing everything typed.
class DiscardGuard extends StatelessWidget {
  const DiscardGuard({
    super.key,
    required this.isDirty,
    required this.child,
  });

  final bool Function() isDirty;
  final Widget child;

  static Future<void> handleBack(BuildContext context) async {
    final _DiscardGuardScope? scope =
        context.dependOnInheritedWidgetOfExactType<_DiscardGuardScope>();

    if (scope == null) {
      Navigator.of(context).pop();
      return;
    }

    await scope.onBack();
  }

  @override
  Widget build(BuildContext context) {
    Future<void> onBack() async {
      final bool hadFocus =
          FocusManager.instance.primaryFocus?.hasFocus ?? false;

      if (hadFocus) {
        FocusScope.of(context).unfocus();
        return;
      }

      if (!isDirty()) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final bool? discard = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text(
              "What you've entered on this screen will be lost.",
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Keep editing'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Discard'),
              ),
            ],
          );
        },
      );

      if (discard == true && context.mounted) {
        Navigator.of(context).pop();
      }
    }

    return _DiscardGuardScope(
      onBack: onBack,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) {
            return;
          }

          onBack();
        },
        child: child,
      ),
    );
  }
}

class _DiscardGuardScope extends InheritedWidget {
  const _DiscardGuardScope({
    required this.onBack,
    required super.child,
  });

  final Future<void> Function() onBack;

  @override
  bool updateShouldNotify(_DiscardGuardScope oldWidget) {
    return false;
  }
}
/// Thin strip shown at the top of a panel when the app started up with
/// no connection and is showing the last-known signed-in profile (see
/// `AuthProvider.restoreSession`). Collapses to nothing once a request
/// succeeds and `restoredFromCache` clears, so it never lingers once the
/// connection is actually back.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final bool offline = context.watch<AuthProvider>().restoredFromCache;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: !offline
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey<bool>(true),
              width: double.infinity,
              color: const Color(0xFFD97706),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.cloud_off, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline - showing data from your last session.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Wrap a provider's `refresh`/`load` call with this for pull-to-refresh.
///
/// A provider keeps old data on screen when a refresh fails (so a flaky
/// connection does not blank out what somebody was looking at), which
/// means its own `error` getter is deliberately not wired into the main
/// error view while there is cached data to show. Without this, that
/// silence reads as "nothing happened" - the spinner stops and nothing
/// else occurs, online or offline. This surfaces the same `error` as a
/// snackbar so a failed refresh is never silent.
Future<void> refreshWithFeedback(
  BuildContext context,
  Future<void> Function() refresh,
  String? Function() errorOf,
) async {
  await refresh();

  if (!context.mounted) {
    return;
  }

  final String? error = errorOf();

  if (error == null) {
    return;
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error)));
}

/// Single metric tile. The number carries the card - label stays quiet.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 16, color: color),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 26,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact number + caption, for the three-across rows on dashboards.
class MiniStat extends StatelessWidget {
  const MiniStat({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  final int value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: <Widget>[
              Container(
                height: 3,
                width: 22,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$value',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 25,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill for status, priority and role values.
class LabelChip extends StatelessWidget {
  const LabelChip({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.dense = true,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 11,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Labelled progress row: `Completed   12 of 40` + bar.
class ProgressRow extends StatelessWidget {
  const ProgressRow({
    super.key,
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double fraction = total == 0 ? 0 : value / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(label, style: theme.textTheme.bodyMedium),
              ),
              Text(
                '$value of $total',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleMedium),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Avatar that falls back to initials.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 20,
    this.color,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final Color? color;

  String get _initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = color ?? Theme.of(context).colorScheme.primary;
    final String? url = imageUrl;

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: base.withValues(alpha: 0.12),
        backgroundImage: NetworkImage(url),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: base.withValues(alpha: 0.12),
      child: Text(
        _initials,
        style: TextStyle(
          color: base,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

/// The greeting block every role dashboard opens with.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    super.key,
    required this.name,
    required this.subtitle,
    this.trailing,
  });

  final String name;
  final String subtitle;
  final Widget? trailing;

  String get _timeOfDay {
    final int hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning';
    }

    if (hour < 17) {
      return 'Good afternoon';
    }

    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String displayName = name.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _timeOfDay,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                // The full name, not just its first word: for an account
                // whose display name happens to be two title-case words
                // (seed/demo data such as "Project Manager"), taking the
                // first word alone used to read as a wrong, truncated
                // greeting ("Good afternoon, Project").
                displayName.isEmpty ? 'Welcome back' : displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

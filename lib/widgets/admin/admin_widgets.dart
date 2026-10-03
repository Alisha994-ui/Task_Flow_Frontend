import 'package:flutter/material.dart';

/// Shared building blocks. Everything here follows AppTheme, so changing
/// the palette there changes these too.

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
              const SizedBox(height: 14),
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
    final String firstName =
        name.trim().isEmpty ? '' : name.trim().split(' ').first;

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
                firstName.isEmpty ? 'Welcome back' : firstName,
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

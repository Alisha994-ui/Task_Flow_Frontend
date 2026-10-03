import 'package:flutter/material.dart';

/// Wraps a screen body so loading, failure and empty states look the same
/// everywhere in the admin panel.
class AsyncView extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.isLoading,
    required this.error,
    required this.isEmpty,
    required this.onRetry,
    required this.child,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage = 'Create the first record to get started.',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyAction,
  });

  final bool isLoading;
  final String? error;
  final bool isEmpty;
  final Future<void> Function() onRetry;
  final Widget child;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return _ErrorState(message: error!, onRetry: onRetry);
    }

    if (isEmpty) {
      return RefreshIndicator(
        onRefresh: onRetry,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            _EmptyState(
              icon: emptyIcon,
              title: emptyTitle,
              message: emptyMessage,
              action: emptyAction,
            ),
          ],
        ),
      );
    }

    return child;
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 24,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Could not load this data',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => onRetry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

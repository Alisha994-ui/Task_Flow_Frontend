import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/admin/async_view.dart';
import '../manager/task_detail_screen.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key, this.canManageTasks = true});

  /// False for an employee - the task they open from here is read-only
  /// apart from its status.
  final bool canManageTasks;

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().ensureLoaded();
      }
    });
  }

  Future<void> _open(NotificationModel notification) async {
    final NotificationProvider provider = context.read<NotificationProvider>();

    await provider.markRead(notification);

    if (!mounted || notification.task == null) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(
          taskId: notification.task!,
          canManage: widget.canManageTasks,
        ),
      ),
    );
  }

  Future<void> _markAll() async {
    final NotificationProvider provider = context.read<NotificationProvider>();
    final bool ok = await provider.markAllRead();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ok ? 'All marked as read' : 'Could not mark them read'),
          backgroundColor: ok ? null : Theme.of(context).colorScheme.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NotificationProvider provider =
        context.watch<NotificationProvider>();
    final List<NotificationModel> items = provider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          if (provider.hasUnread)
            TextButton(
              onPressed: provider.isBusy ? null : _markAll,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: <Widget>[
                ChoiceChip(
                  label: const Text('All'),
                  selected: !provider.unreadOnly,
                  onSelected: (_) => provider.setUnreadOnly(false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    provider.unreadCount == 0
                        ? 'Unread'
                        : 'Unread (${provider.unreadCount})',
                  ),
                  selected: provider.unreadOnly,
                  onSelected: (_) => provider.setUnreadOnly(true),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView(
              isLoading:
                  provider.isLoading && provider.allNotifications.isEmpty,
              error: provider.allNotifications.isEmpty ? provider.error : null,
              isEmpty: items.isEmpty,
              onRetry: provider.refresh,
              emptyIcon: Icons.notifications_none,
              emptyTitle: provider.unreadOnly
                  ? 'Nothing unread'
                  : 'No notifications yet',
              emptyMessage: provider.unreadOnly
                  ? 'You are all caught up.'
                  : 'Task assignments, comments and deadline reminders '
                      'land here.',
              child: RefreshIndicator(
                onRefresh: provider.refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final NotificationModel item = items[index];
                    final Color color = NotificationType.color(item.type);

                    return Card(
                      margin: EdgeInsets.zero,
                      color: item.isRead
                          ? null
                          : color.withValues(alpha: 0.06),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            NotificationType.icon(item.type),
                            size: 18,
                            color: color,
                          ),
                        ),
                        title: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: item.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            if (!item.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const SizedBox(height: 2),
                            Text(
                              item.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${NotificationType.label(item.type)} · '
                              '${timeAgo(item.createdAt)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        trailing: item.task == null
                            ? null
                            : const Icon(Icons.chevron_right),
                        onTap: () => _open(item),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notification_provider.dart';
import '../screens/notifications/notification_list_screen.dart';

/// AppBar bell with an unread badge. Drop it into any panel's actions.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.canManageTasks = true});

  /// Passed through to the task a notification opens.
  final bool canManageTasks;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int unread = context.watch<NotificationProvider>().unreadCount;

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => NotificationListScreen(
                canManageTasks: canManageTasks,
              ),
            ),
          ),
        ),
        if (unread > 0)
          Positioned(
            top: 8,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 17),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

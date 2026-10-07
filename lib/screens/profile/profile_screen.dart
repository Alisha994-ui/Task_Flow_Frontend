import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/project_constants.dart';
import '../../core/push/push_service.dart';
import '../../core/utils/contact.dart';
import '../../models/user_model.dart';
import '../../providers/admin_dashboard_provider.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/coach_provider.dart';
import '../../providers/manager_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/time_log_provider.dart';
import '../../providers/user_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/admin/admin_widgets.dart';

/// One profile screen for every role: who you are signed in as, and the
/// way out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const String routeName = '/profile';

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will need your username and password to get back in.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Stay signed in'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    await signOut(context);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthProvider auth = context.watch<AuthProvider>();
    final UserModel? user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: <Widget>[
          Center(
            child: Column(
              children: <Widget>[
                UserAvatar(
                  name: user?.fullName ?? 'User',
                  imageUrl: user?.profileImage,
                  radius: 44,
                  color: user == null
                      ? null
                      : UserRoles.color(user.role),
                ),
                const SizedBox(height: 14),
                Text(
                  user?.fullName ?? 'Signed in',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                if (user != null)
                  Text(
                    '@${user.username}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 10),
                if (user != null)
                  LabelChip(
                    text: UserRoles.label(user.role),
                    color: UserRoles.color(user.role),
                    dense: false,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Account'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _InfoTile(
                  icon: Icons.mail_outline,
                  label: 'Email',
                  value: (user?.email.isEmpty ?? true)
                      ? 'Not provided'
                      : user!.email,
                  onTap: (user?.email.isEmpty ?? true)
                      ? null
                      : () => openMail(context, user!.email),
                ),
                const Divider(height: 1, indent: 56),
                _InfoTile(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: (user?.phone == null || user!.phone!.isEmpty)
                      ? 'Not provided'
                      : user.phone!,
                  onTap:
                      (user?.phone == null || user!.phone!.isEmpty)
                          ? null
                          : () => openDialer(context, user.phone!),
                ),
                const Divider(height: 1, indent: 56),
                _InfoTile(
                  icon: Icons.badge_outlined,
                  label: 'Role',
                  value: user == null
                      ? '-'
                      : UserRoles.label(user.role),
                ),
                const Divider(height: 1, indent: 56),
                _InfoTile(
                  icon: Icons.toggle_on_outlined,
                  label: 'Status',
                  value: (user?.status ?? false)
                      ? 'Active'
                      : 'Inactive',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'TaskFlow',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Signs out and sends the person back to the login screen.
///
/// Every provider is cleared first - they live above the navigator, so
/// without this the next person to sign in would briefly see the previous
/// user's tasks, notifications and counts.
Future<void> signOut(BuildContext context) async {
  // Do not make logout wait for the push notification API.
  // The unregister request runs in the background.
  unawaited(
    PushService.unregisterDevice().catchError((_) {}),
  );

  if (!context.mounted) {
    return;
  }

  context.read<AssistantProvider>().reset();
  context.read<CoachProvider>().reset();
  context.read<TaskProvider>().reset();
  context.read<NotificationProvider>().reset();
  context.read<TimeLogProvider>().reset();
  context.read<ProjectProvider>().reset();
  context.read<UserProvider>().reset();
  context.read<TeamProvider>().reset();
  context.read<ManagerProvider>().reset();
  context.read<AdminDashboardProvider>().reset();

  await context.read<AuthProvider>().logout();

  if (!context.mounted) {
    return;
  }

  Navigator.of(context).pushNamedAndRemoveUntil(
    AppRoutes.login,
    (Route<dynamic> route) => false,
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      trailing: onTap == null
          ? null
          : Icon(
              Icons.north_east,
              size: 16,
              color: theme.colorScheme.primary,
            ),
      leading: Icon(
        icon,
        color: onTap == null
            ? theme.colorScheme.outline
            : theme.colorScheme.primary,
      ),
      title: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}
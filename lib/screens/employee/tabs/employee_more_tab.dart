import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../widgets/reporting_line_card.dart';
import '../../../providers/team_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../core/utils/reporting_line.dart';

import '../../../core/constants/project_constants.dart';
import '../../../models/team_model.dart';
import '../../../models/time_log_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/manager_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/time_log_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../discussion/my_discussions_screen.dart';
import '../../notifications/notification_list_screen.dart';
import '../../profile/profile_screen.dart';
import '../employee_time_logs_screen.dart';

/// Navigation only. Task counts are on the Today tab; identity, contacts
/// and sign out are on the profile screen.
class EmployeeMoreTab extends StatelessWidget {
  const EmployeeMoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ManagerProvider scope = context.watch<ManagerProvider>();
    final UserProvider users = context.watch<UserProvider>();

    // Read out of the team and project links - the API has no
    // "reports to" field.
    final ReportingLine line = resolveReportingLine(
      userId: scope.managerId,
      role: scope.roleLabel,
      users: users.allUsers,
      teams: context.watch<TeamProvider>().allTeams,
      projects: context.watch<ProjectProvider>().allProjects,
    );
    final TimeLogProvider timer = context.watch<TimeLogProvider>();
    final NotificationProvider notifications =
        context.watch<NotificationProvider>();

    final UserModel? me = users.byId(scope.managerId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  UserAvatar(
                    name: scope.managerName.isEmpty
                        ? 'You'
                        : scope.managerName,
                    imageUrl: me?.profileImage,
                    radius: 24,
                    color: me == null ? null : UserRoles.color(me.role),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          scope.managerName.isEmpty
                              ? 'Your profile'
                              : scope.managerName,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${scope.roleLabel} · profile, contacts, sign out',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('My projects'),
                subtitle: const Text('Open a project to talk to its team'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const MyDiscussionsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Time logs'),
                subtitle: Text(
                  '${formatMinutes(timer.minutesToday)} today · '
                  '${formatMinutes(timer.minutesThisWeek)} this week',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const EmployeeTimeLogsScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.notifications_none),
                title: const Text('Notifications'),
                subtitle: Text(
                  notifications.unreadCount == 0
                      ? 'Nothing unread'
                      : '${notifications.unreadCount} unread',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationListScreen(
                      canManageTasks: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Who to ask',
          subtitle: 'Tap anyone to send them an email',
        ),
        const SizedBox(height: 8),
        ReportingLineCard(line: line),
        if (line.teams.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.groups_outlined,
                color: Theme.of(context).colorScheme.outline,
              ),
              title: Text(
                line.teams.map((TeamModel t) => t.name).join(', '),
              ),
              subtitle: Text(
                line.teams.length == 1 ? 'Your team' : 'Your teams',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

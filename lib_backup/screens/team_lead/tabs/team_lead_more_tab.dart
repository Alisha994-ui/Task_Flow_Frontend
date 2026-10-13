import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/project_constants.dart';
import '../../../core/utils/reporting_line.dart';
import '../../../models/team_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/manager_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/team_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/reporting_line_card.dart';
import '../../manager/manager_reports_screen.dart';
import '../../notifications/notification_list_screen.dart';
import '../../profile/profile_screen.dart';

/// Navigation only. Identity, reporting line and sign out
/// are handled by the profile screen.
class TeamLeadMoreTab extends StatelessWidget {
  const TeamLeadMoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final ManagerProvider scope =
        context.watch<ManagerProvider>();

    final TaskProvider tasks =
        context.watch<TaskProvider>();

    final TeamProvider teams =
        context.watch<TeamProvider>();

    final UserProvider users =
        context.watch<UserProvider>();

    final ProjectProvider projects =
        context.watch<ProjectProvider>();

    final NotificationProvider notifications =
        context.watch<NotificationProvider>();

    final int teamLeadId = scope.managerId ?? -1;

    // ONLY teams where the current user is Team Lead.
    final List<TeamModel> myTeams =
        teams.teamsForTeamLead(teamLeadId);

    // ONLY members from the Team Lead's own teams.
    final Set<int> myMemberIds =
        teams.memberIdsForTeamLead(teamLeadId);

    final List<UserModel> myMembers = users.allUsers
        .where(
          (UserModel user) =>
              myMemberIds.contains(user.id),
        )
        .toList();

    // Reporting line can include Admins and Project Managers,
    // while team information remains scoped to the Team Lead's
    // own teams.
    final ReportingLine line = resolveReportingLine(
      userId: scope.managerId,
      role: scope.roleLabel,
      users: users.allUsers,
      teams: myTeams,
      projects: projects.allProjects,
    );

    final int myTeamCount = myTeams.length;

    final UserModel? me =
        users.byId(scope.managerId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        32,
      ),
      children: <Widget>[
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () =>
                Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const ProfileScreen(),
              ),
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
                    color: me == null
                        ? null
                        : UserRoles.color(me.role),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          scope.managerName.isEmpty
                              ? 'Your profile'
                              : scope.managerName,
                          style:
                              theme.textTheme.titleMedium,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${scope.roleLabel} · $myTeamCount '
                          '${myTeamCount == 1 ? 'team' : 'teams'}',
                          style:
                              theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                  ),
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
                leading: const Icon(
                  Icons.insights_outlined,
                ),
                title: const Text('Reports'),
                subtitle: Text(
                  '${tasks.allTasks.length} tasks analysed',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () =>
                    Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const ManagerReportsScreen(),
                  ),
                ),
              ),
              const Divider(
                height: 1,
                indent: 56,
              ),
              ListTile(
                leading: const Icon(
                  Icons.notifications_none,
                ),
                title: const Text(
                  'Notifications',
                ),
                subtitle: Text(
                  notifications.unreadCount == 0
                      ? 'Nothing unread'
                      : '${notifications.unreadCount} unread',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () =>
                    Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const NotificationListScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        const SectionHeader(
          title: 'Who to ask',
          subtitle:
              'Admins, managers and people from your team',
        ),

        const SizedBox(height: 8),

        ReportingLineCard(line: line),

        if (myTeams.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.groups_outlined,
                color: Theme.of(context)
                    .colorScheme
                    .outline,
              ),
              title: Text(
                myTeams
                    .map(
                      (TeamModel team) =>
                          team.name,
                    )
                    .join(', '),
              ),
              subtitle: Text(
                myTeams.length == 1
                    ? 'Your team'
                    : 'Your teams',
              ),
            ),
          ),
        ],

        if (myMembers.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.people_outline,
                color: Theme.of(context)
                    .colorScheme
                    .outline,
              ),
              title: Text(
                '${myMembers.length} '
                '${myMembers.length == 1 ? 'member' : 'members'}',
              ),
              subtitle: const Text(
                'Members from your teams only',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
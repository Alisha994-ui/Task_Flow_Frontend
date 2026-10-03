import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/project_constants.dart';
import '../../../models/task_model.dart';
import '../../../models/team_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/manager_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/team_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/admin/async_view.dart';
import '../team_lead_member_detail_screen.dart';

/// Everyone on the teams this user leads, with how much each is carrying.
class TeamLeadMembersTab extends StatelessWidget {
  const TeamLeadMembersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final TeamProvider teams = context.watch<TeamProvider>();
    final UserProvider users = context.watch<UserProvider>();
    final TaskProvider tasks = context.watch<TaskProvider>();
    final ManagerProvider scope = context.watch<ManagerProvider>();

    final List<TeamModel> myTeams = teams.allTeams
        .where((TeamModel t) => t.teamLead == scope.managerId)
        .toList();

    final Set<int> memberIds = <int>{
      for (final TeamModel team in myTeams) ...team.members,
    };

    return AsyncView(
      isLoading: teams.isLoading && teams.allTeams.isEmpty,
      error: teams.allTeams.isEmpty ? teams.error : null,
      isEmpty: myTeams.isEmpty,
      onRetry: teams.refresh,
      emptyIcon: Icons.groups_outlined,
      emptyTitle: 'No team yet',
      emptyMessage:
          'Once an admin makes you the lead of a team, its members appear here.',
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait<void>(<Future<void>>[
            teams.refresh(),
            tasks.refresh(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: StatCard(
                    label: 'People',
                    value: memberIds.length,
                    icon: Icons.people_outline,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Open tasks',
                    value: tasks.allTasks
                        .where((TaskModel t) => !t.isCompleted)
                        .length,
                    icon: Icons.pending_actions_outlined,
                    color: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Overdue',
                    value: tasks.overdueTasks.length,
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            ...myTeams.map(
              (TeamModel team) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _TeamBlock(team: team, users: users, tasks: tasks),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({
    required this.team,
    required this.users,
    required this.tasks,
  });

  final TeamModel team;
  final UserProvider users;
  final TaskProvider tasks;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: team.name,
          subtitle: team.description.trim().isEmpty
              ? '${team.members.length} '
                  '${team.members.length == 1 ? 'member' : 'members'}'
              : team.description,
        ),
        const SizedBox(height: 8),
        if (team.members.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'This team has no members yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ...team.members.map((int memberId) {
            final UserModel? user = users.byId(memberId);
            final String name = users.nameFor(memberId);

            final List<TaskModel> theirs = tasks.allTasks
                .where((TaskModel t) => t.assignee == memberId)
                .toList();

            final int open =
                theirs.where((TaskModel t) => !t.isCompleted).length;
            final int overdue =
                theirs.where((TaskModel t) => t.isOverdue).length;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: UserAvatar(
                    name: name,
                    imageUrl: user?.profileImage,
                    color: user == null ? null : UserRoles.color(user.role),
                  ),
                  title: Text(name, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    user == null
                        ? 'Member'
                        : UserRoles.label(user.role),
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      LabelChip(
                        text: '$open open',
                        color: open == 0
                            ? const Color(0xFF059669)
                            : const Color(0xFF2563EB),
                      ),
                      if (overdue > 0)
                        LabelChip(
                          text: '$overdue late',
                          color: const Color(0xFFDC2626),
                        ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          TeamLeadMemberDetailScreen(userId: memberId),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/project_constants.dart';
import '../../../core/utils/contact.dart';
import '../../../models/project_model.dart';
import '../../../models/team_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/manager_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/team_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/admin/async_view.dart';

/// People the manager works with: every team attached to one of their
/// projects, plus the teams they lead.
class ManagerTeamTab extends StatelessWidget {
  const ManagerTeamTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ProjectProvider projects = context.watch<ProjectProvider>();
    final ManagerProvider manager = context.watch<ManagerProvider>();
    final TeamProvider teams = context.watch<TeamProvider>();
    final UserProvider users = context.watch<UserProvider>();

    final Set<int> ledTeamIds = teams.allTeams
        .where((TeamModel t) => t.teamLead == manager.managerId)
        .map((TeamModel t) => t.id)
        .toSet();

    final List<ProjectModel> mine =
        manager.myProjects(projects.allProjects, ledTeamIds: ledTeamIds);

    final Set<int> teamIds = <int>{
      ...ledTeamIds,
      ...mine
          .where((ProjectModel p) => p.team != null)
          .map((ProjectModel p) => p.team!),
    };

    final List<TeamModel> myTeams = teams.allTeams
        .where((TeamModel t) => teamIds.contains(t.id))
        .toList();

    final Set<int> peopleIds = <int>{
      for (final TeamModel team in myTeams) ...team.members,
      for (final TeamModel team in myTeams)
        if (team.teamLead != null) team.teamLead!,
    };

    return AsyncView(
      isLoading: (teams.isLoading || projects.isLoading) &&
          teams.allTeams.isEmpty,
      error: teams.allTeams.isEmpty ? teams.error : null,
      isEmpty: myTeams.isEmpty,
      onRetry: teams.refresh,
      emptyIcon: Icons.groups_outlined,
      emptyTitle: 'No team yet',
      emptyMessage:
          'Once a project with a team is assigned to you, its members show up here.',
      child: RefreshIndicator(
        onRefresh: teams.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: StatCard(
                    label: 'Teams',
                    value: myTeams.length,
                    icon: Icons.groups_outlined,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'People',
                    value: peopleIds.length,
                    icon: Icons.people_outline,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Projects',
                    value: mine.length,
                    icon: Icons.folder_outlined,
                    color: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            ...myTeams.map(
              (TeamModel team) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _TeamSection(
                  team: team,
                  users: users,
                  projectCount: mine
                      .where((ProjectModel p) => p.team == team.id)
                      .length,
                  isLead: team.teamLead == manager.managerId,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({
    required this.team,
    required this.users,
    required this.projectCount,
    required this.isLead,
  });

  final TeamModel team;
  final UserProvider users;
  final int projectCount;
  final bool isLead;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    team.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isLead)
                  const LabelChip(
                    text: 'You lead this',
                    color: Color(0xFF0D9488),
                    icon: Icons.star_outline,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$projectCount of your ${projectCount == 1 ? 'project' : 'projects'} '
              '· ${team.members.length} ${team.members.length == 1 ? 'member' : 'members'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (team.members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'This team has no members yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...team.members.map((int memberId) {
                final UserModel? user = users.byId(memberId);
                final String name = users.nameFor(memberId);
                final String email = user?.email ?? '';
                final bool isTeamLead = team.teamLead == memberId;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: UserAvatar(
                    name: name,
                    imageUrl: user?.profileImage,
                    radius: 18,
                    color: user == null ? null : UserRoles.color(user.role),
                  ),
                  title: Text(name, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    user == null
                        ? 'Member'
                        : '${UserRoles.label(user.role)}'
                            '${isTeamLead ? ' · Team lead' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: email.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Email $email',
                          icon: Icon(
                            Icons.mail_outline,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () => openMail(context, email),
                        ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

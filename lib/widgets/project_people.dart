import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/project_constants.dart';
import '../core/utils/app_date_utils.dart';
import '../models/project_member_model.dart';
import '../models/project_model.dart';
import '../models/team_model.dart';
import '../models/user_model.dart';
import '../providers/team_provider.dart';
import '../providers/user_provider.dart';
import 'admin/admin_widgets.dart';

/// Everyone on a project, from both places the backend keeps them.
///
/// A project has a team, and a team has members - those people are on
/// the project by definition, and the API already gives them access to
/// its tasks and its discussion. Separately, ProjectMember rows let
/// somebody be added who is not in that team.
///
/// Showing only the second list - which is what the Members tab used to
/// do - made a project with a team look empty.
class ProjectPeople extends StatelessWidget {
  const ProjectPeople({
    super.key,
    required this.project,
    required this.members,
    this.onAdd,
    this.onRemove,
    this.busy = false,
  });

  final ProjectModel project;

  /// ProjectMember rows - people added to this project on their own.
  final List<ProjectMemberModel> members;

  final VoidCallback? onAdd;
  final void Function(ProjectMemberModel)? onRemove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TeamProvider teams = context.watch<TeamProvider>();
    final UserProvider users = context.watch<UserProvider>();

    final TeamModel? team = teams.byId(project.team);

    // Someone can be in the team and also added individually. Show them
    // once, under the team.
    final Set<int> teamIds = <int>{
      if (team != null) ...team.members,
      if (team?.teamLead != null) team!.teamLead!,
    };

    final List<ProjectMemberModel> extras = members
        .where((ProjectMemberModel m) => !teamIds.contains(m.user))
        .toList();

    final int total = teamIds.length + extras.length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        SectionHeader(
          title: 'People',
          subtitle: total == 0
              ? 'Nobody on this project yet'
              : '$total with access to its tasks and discussion',
          trailing: onAdd == null
              ? null
              : FilledButton.tonalIcon(
                  onPressed: busy ? null : onAdd,
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Add'),
                ),
        ),
        const SizedBox(height: 14),

        // ------------------------------------------------- the team
        if (team == null)
          Card(
            child: ListTile(
              leading: Icon(
                Icons.groups_outlined,
                color: theme.colorScheme.outline,
              ),
              title: const Text('No team on this project'),
              subtitle: Text(
                'Set one when you edit the project, and its members get '
                'access automatically.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          )
        else ...<Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.groups_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  team.name,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${teamIds.length} from the team',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (teamIds.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  '"${team.name}" has no members yet. Add them to the team '
                  'and they appear here.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: teamIds.map((int id) {
                  final UserModel? user = users.byId(id);
                  final bool isLead = team.teamLead == id;
                  final bool isLast = id == teamIds.last;

                  return Column(
                    children: <Widget>[
                      ListTile(
                        leading: UserAvatar(
                          name: users.nameFor(id),
                          imageUrl: user?.profileImage,
                          color:
                              user == null ? null : UserRoles.color(user.role),
                        ),
                        title: Text(
                          users.nameFor(id),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          user == null
                              ? 'Team member'
                              : UserRoles.label(user.role),
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: isLead
                            ? const LabelChip(
                                text: 'Lead',
                                color: Color(0xFF0D9488),
                                icon: Icons.star_outline,
                              )
                            : null,
                      ),
                      if (!isLast) const Divider(height: 1, indent: 68),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Team members come from the team itself. To change them, edit '
            'the team rather than this project.',
            style: theme.textTheme.bodySmall,
          ),
        ],

        // -------------------------------------------- added separately
        const SizedBox(height: 22),
        Row(
          children: <Widget>[
            Icon(
              Icons.person_add_alt_1_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Added to this project',
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(
              '${extras.length}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (extras.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                onAdd == null
                    ? 'Nobody has been added on top of the team.'
                    : 'Use Add for anyone who needs access but is not in '
                        'the team.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: extras.map((ProjectMemberModel member) {
                final UserModel? user = users.byId(member.user);
                final String name = member.userName.isNotEmpty
                    ? member.userName
                    : users.nameFor(member.user);
                final bool isLast = member == extras.last;

                return Column(
                  children: <Widget>[
                    ListTile(
                      leading: UserAvatar(
                        name: name,
                        imageUrl: user?.profileImage,
                        color:
                            user == null ? null : UserRoles.color(user.role),
                      ),
                      title: Text(name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        user == null
                            ? 'Joined ${formatDate(member.joinedAt, fallback: 'recently')}'
                            : UserRoles.label(user.role),
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: onRemove == null
                          ? null
                          : IconButton(
                              tooltip: 'Remove from project',
                              onPressed:
                                  busy ? null : () => onRemove!(member),
                              icon: Icon(
                                Icons.person_remove_outlined,
                                color: theme.colorScheme.error,
                              ),
                            ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 68),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

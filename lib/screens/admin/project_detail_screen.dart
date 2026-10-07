import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/project_constants.dart';
import '../../core/utils/app_date_utils.dart';
import '../../models/project_member_model.dart';
import '../../models/project_model.dart';
import '../../models/user_model.dart';
import '../../providers/project_detail_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../widgets/admin/async_view.dart';
import '../../widgets/project_people.dart';
import '../discussion/project_discussion_screen.dart';
import 'project_form_screen.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProjectDetailProvider>(
      create: (_) => ProjectDetailProvider(projectId)..load(),
      child: const _ProjectDetailView(),
    );
  }
}

class _ProjectDetailView extends StatelessWidget {
  const _ProjectDetailView();

  void _snack(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  Future<void> _edit(BuildContext context, ProjectModel project) async {
    final ProjectDetailProvider detail = context.read<ProjectDetailProvider>();

    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProjectFormScreen(project: project),
      ),
    );

    if (saved == true) {
      await detail.refresh();
    }
  }

  Future<void> _addMember(BuildContext context) async {
    final ProjectDetailProvider detail = context.read<ProjectDetailProvider>();
    final UserProvider users = context.read<UserProvider>();

    await users.ensureLoaded();

    if (!context.mounted) {
      return;
    }

    final int? userId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return _AddMemberSheet(
          users: users.allUsers,
          excludedUserIds: detail.memberUserIds,
        );
      },
    );

    if (userId == null) {
      return;
    }

    final bool ok = await detail.addMember(userId);

    if (!context.mounted) {
      return;
    }

    _snack(
      context,
      ok ? 'Member added' : (detail.error ?? 'Could not add the member'),
      isError: !ok,
    );
  }

  Future<void> _removeMember(
    BuildContext context,
    ProjectMemberModel member,
  ) async {
    final ProjectDetailProvider detail = context.read<ProjectDetailProvider>();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Remove this member?'),
          content: Text(
            '${member.userName} will lose access to this project.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final bool ok = await detail.removeMember(member.id);

    if (!context.mounted) {
      return;
    }

    _snack(
      context,
      ok ? 'Member removed' : (detail.error ?? 'Could not remove the member'),
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProjectDetailProvider detail =
        context.watch<ProjectDetailProvider>();
    final ProjectModel? project = detail.project;

    // Same shape as the manager's project screen: Discussion is a tab,
    // in the project, like it is for every other role.
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(project?.name ?? 'Project'),
          actions: <Widget>[
            if (project != null)
              IconButton(
                tooltip: 'Edit project',
                onPressed: () => _edit(context, project),
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Overview'),
              Tab(text: 'Members'),
              Tab(text: 'Discussion'),
            ],
          ),
        ),
        body: AsyncView(
          isLoading: detail.isLoading && project == null,
          error: project == null ? detail.error : null,
          isEmpty: false,
          onRetry: detail.refresh,
          child: project == null
              ? const SizedBox.shrink()
              : TabBarView(
                  children: <Widget>[
                    RefreshIndicator(
                      onRefresh: detail.refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: <Widget>[
                          _SummaryCard(project: project),
                          if (detail.progress.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 20),
                            const SectionHeader(
                              title: 'Progress',
                              subtitle:
                                  'Reported by the project progress endpoint',
                            ),
                            const SizedBox(height: 8),
                            _ProgressCard(data: detail.progress),
                          ],
                        ],
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: detail.refresh,
                      child: ProjectPeople(
                        project: project,
                        members: detail.members,
                        busy: detail.isMemberBusy,
                        onAdd: () => _addMember(context),
                        onRemove: (ProjectMemberModel member) =>
                            _removeMember(context, member),
                      ),
                    ),
                    ProjectDiscussionScreen(
                      projectId: project.id,
                      projectName: project.name,
                      embedded: true,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final UserProvider users = context.watch<UserProvider>();
    final TeamProvider teams = context.watch<TeamProvider>();
    final bool overdue = isOverdue(project.endDate, project.status);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                LabelChip(
                  text: ProjectStatus.label(project.status),
                  color: ProjectStatus.color(project.status),
                ),
                LabelChip(
                  text: ProjectPriority.label(project.priority),
                  color: ProjectPriority.color(project.priority),
                  icon: Icons.flag_outlined,
                ),
                if (project.isArchived)
                  const LabelChip(
                    text: 'Archived',
                    color: Color(0xFF6B7280),
                    icon: Icons.inventory_2_outlined,
                  ),
                if (overdue)
                  const LabelChip(
                    text: 'Past due date',
                    color: Color(0xFFDC2626),
                    icon: Icons.schedule,
                  ),
              ],
            ),
            if (project.description.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(project.description, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (project.progress / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${project.progress}%',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Manager',
              value: users.nameFor(project.manager),
            ),
            _InfoRow(
              icon: Icons.groups_outlined,
              label: 'Team',
              value: teams.nameFor(project.team),
            ),
            _InfoRow(
              icon: Icons.play_circle_outline,
              label: 'Starts',
              value: formatDate(project.startDate),
            ),
            _InfoRow(
              icon: Icons.event_outlined,
              label: 'Ends',
              value: formatDate(project.endDate),
            ),
            _InfoRow(
              icon: Icons.update,
              label: 'Updated',
              value: formatDate(project.updatedAt, fallback: 'Unknown'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 12),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// The progress endpoint shape is not fixed, so every key is rendered
/// generically and any percentage value also gets a bar.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.entries.map((MapEntry<String, dynamic> entry) {
            final bool isPercent = entry.value is num &&
                (entry.key.contains('progress') ||
                    entry.key.contains('percent') ||
                    entry.key.contains('rate'));

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          humanizeChoice(entry.key),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        _formatValue(entry.value),
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                  ),
                  if (isPercent) ...<Widget>[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ((entry.value as num) / 100).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) {
      return '-';
    }

    if (value is double) {
      return value.toStringAsFixed(1);
    }

    if (value is List) {
      return '${value.length}';
    }

    if (value is Map) {
      return '${value.length} fields';
    }

    return value.toString();
  }
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({required this.users, required this.excludedUserIds});

  final List<UserModel> users;
  final Set<int> excludedUserIds;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String query = _query.trim().toLowerCase();

    final List<UserModel> candidates = widget.users.where((UserModel u) {
      if (widget.excludedUserIds.contains(u.id)) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return u.fullName.toLowerCase().contains(query) ||
          u.username.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Add a member',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: false,
                    onChanged: (String value) =>
                        setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search people',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: candidates.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Everyone matching this search is already on the project.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (BuildContext context, int index) {
                        final UserModel user = candidates[index];

                        return ListTile(
                          leading: UserAvatar(
                            name: user.fullName,
                            imageUrl: user.profileImage,
                            color: UserRoles.color(user.role),
                          ),
                          title: Text(user.fullName),
                          subtitle: Text(UserRoles.label(user.role)),
                          onTap: () => Navigator.of(context).pop(user.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

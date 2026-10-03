import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/task_constants.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';
import '../../../models/task_stats_model.dart';
import '../../../models/team_model.dart';
import '../../../providers/manager_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/team_provider.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/admin/async_view.dart';
import '../../../widgets/manager/manager_project_card.dart';
import '../../../widgets/manager/task_tile.dart';
import '../manager_project_detail_screen.dart';
import '../task_actions.dart';
import '../task_detail_screen.dart';

/// Answers one question: what needs the manager's attention today?
///
/// The headline numbers live here; the detail behind them lives in the
/// Projects and Tasks tabs, so nothing is said twice.
class ManagerDashboardTab extends StatelessWidget {
  const ManagerDashboardTab({
    super.key,
    required this.onSeeAllProjects,
    required this.onSeeAllTasks,
  });

  final VoidCallback onSeeAllProjects;
  final VoidCallback onSeeAllTasks;

  @override
  Widget build(BuildContext context) {
    final ProjectProvider projects = context.watch<ProjectProvider>();
    final ManagerProvider manager = context.watch<ManagerProvider>();
    final TeamProvider teams = context.watch<TeamProvider>();
    final TaskProvider tasks = context.watch<TaskProvider>();

    final Set<int> ledTeamIds = teams.allTeams
        .where((TeamModel t) => t.teamLead == manager.managerId)
        .map((TeamModel t) => t.id)
        .toSet();

    final List<ProjectModel> mine =
        manager.myProjects(projects.allProjects, ledTeamIds: ledTeamIds);

    final TaskStatsModel stats = tasks.stats;
    final int unassigned = tasks.unassignedTasks.length;

    return AsyncView(
      isLoading: projects.isLoading && projects.allProjects.isEmpty,
      error: projects.allProjects.isEmpty ? projects.error : null,
      isEmpty: false,
      onRetry: projects.refresh,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait<void>(<Future<void>>[
            projects.refresh(),
            tasks.refresh(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            GreetingHeader(
              name: manager.managerName,
              subtitle: mine.isEmpty
                  ? 'No projects are assigned to you yet.'
                  : '${mine.length} ${mine.length == 1 ? 'project' : 'projects'}'
                      ' · ${stats.total} tasks',
            ),
            if (mine.isEmpty) ...<Widget>[
              const SizedBox(height: 24),
              _NoProjectsCard(onRefresh: projects.refresh),
            ] else ...<Widget>[
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: MiniStat(
                      value: stats.inProgress,
                      label: 'In progress',
                      color: TaskStatus.color(TaskStatus.inProgress),
                      onTap: onSeeAllTasks,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MiniStat(
                      value: stats.overdue,
                      label: 'Overdue',
                      color: const Color(0xFFDC2626),
                      onTap: onSeeAllTasks,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MiniStat(
                      value: unassigned,
                      label: 'Unassigned',
                      color: const Color(0xFFD97706),
                      onTap: onSeeAllTasks,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _NeedsAttention(onSeeAllTasks: onSeeAllTasks),
              const SizedBox(height: 26),
              _Projects(
                projects: mine,
                averageProgress: manager.averageProgress(mine),
                onSeeAll: onSeeAllProjects,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Overdue work first, then anything nobody owns. One list, because both
/// mean the same thing to a manager: this slips unless you act.
class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention({required this.onSeeAllTasks});

  final VoidCallback onSeeAllTasks;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TaskProvider tasks = context.watch<TaskProvider>();

    final List<TaskModel> flagged = <TaskModel>[
      ...tasks.overdueTasks,
      ...tasks.unassignedTasks.where((TaskModel t) => !t.isOverdue),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Needs attention',
          subtitle: flagged.isEmpty
              ? 'Nothing is overdue or unowned'
              : '${flagged.length} ${flagged.length == 1 ? 'task' : 'tasks'} '
                  'late or unassigned',
          trailing: flagged.length > 4
              ? TextButton(
                  onPressed: onSeeAllTasks,
                  child: const Text('See all'),
                )
              : null,
        ),
        const SizedBox(height: 12),
        if (flagged.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Every task is owned and on time.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...flagged.take(4).map(
                (TaskModel task) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TaskTile(
                    task: task,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => TaskDetailScreen(taskId: task.id),
                      ),
                    ),
                    onStatusTap: () => TaskActions.changeStatus(context, task),
                    onAssignTap: () => TaskActions.reassign(context, task),
                  ),
                ),
              ),
      ],
    );
  }
}

class _Projects extends StatelessWidget {
  const _Projects({
    required this.projects,
    required this.averageProgress,
    required this.onSeeAll,
  });

  final List<ProjectModel> projects;
  final int averageProgress;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Your projects',
          subtitle: '$averageProgress% average completion',
          trailing: projects.length > 3
              ? TextButton(
                  onPressed: onSeeAll,
                  child: const Text('See all'),
                )
              : null,
        ),
        const SizedBox(height: 12),
        ...projects.take(3).map(
              (ProjectModel project) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ManagerProjectCard(
                  project: project,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ManagerProjectDetailScreen(
                        projectId: project.id,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _NoProjectsCard extends StatelessWidget {
  const _NoProjectsCard({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.folder_off_outlined,
              size: 26,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text('Nothing assigned yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'An admin needs to set you as the manager on a project, or '
              'make you the lead of a team that owns one.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => onRefresh(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Check again'),
            ),
          ],
        ),
      ),
    );
  }
}

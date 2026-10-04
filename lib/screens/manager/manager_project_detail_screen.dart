import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/project_constants.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/project_rules.dart';
import '../../models/activity_log_model.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../providers/manager_provider.dart';
import '../../providers/project_detail_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/task_service.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../widgets/admin/async_view.dart';
import '../../widgets/manager/task_tile.dart';
import '../../widgets/project_people.dart';
import '../discussion/project_discussion_screen.dart';
import 'task_actions.dart';
import 'task_detail_screen.dart';

/// Project view for a manager: overview, its tasks, its people and the
/// activity feed built from the project's tasks.
class ManagerProjectDetailScreen extends StatelessWidget {
  const ManagerProjectDetailScreen({super.key, required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProjectDetailProvider>(
      create: (_) => ProjectDetailProvider(projectId)..load(),
      child: _ManagerProjectDetailView(projectId: projectId),
    );
  }
}

class _ManagerProjectDetailView extends StatefulWidget {
  const _ManagerProjectDetailView({required this.projectId});

  final int projectId;

  @override
  State<_ManagerProjectDetailView> createState() =>
      _ManagerProjectDetailViewState();
}

class _ManagerProjectDetailViewState extends State<_ManagerProjectDetailView>
    with SingleTickerProviderStateMixin {
  static const int _tasksTab = 1;

  late final TabController _tabs;

  @override
  void initState() {
    super.initState();

    // A controller rather than DefaultTabController, because the FAB
    // has to know which tab is open: on Discussion it would sit on top
    // of the send button.
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int projectId = widget.projectId;
    final ProjectDetailProvider detail =
        context.watch<ProjectDetailProvider>();
    final ProjectModel? project = detail.project;

    // Admins keep full control; a manager or lead can only read a
    // finished project.
    final bool locked =
        context.watch<ManagerProvider>().managerId != null &&
            isProjectClosed(project);

    return Scaffold(
        appBar: AppBar(
          title: Text(project?.name ?? 'Project'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Refresh',
              onPressed: detail.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const <Widget>[
              Tab(text: 'Overview'),
              Tab(text: 'Tasks'),
              Tab(text: 'Members'),
              Tab(text: 'Discussion'),
              Tab(text: 'Activity'),
            ],
          ),
        ),
        // Only on Tasks. Anywhere else it is either useless or, on
        // Discussion, directly over the send button.
        floatingActionButton: (locked || _tabs.index != _tasksTab)
            ? null
            : FloatingActionButton.extended(
                onPressed: () =>
                    TaskActions.create(context, projectId: projectId),
                icon: const Icon(Icons.add),
                label: const Text('New task'),
              ),
        body: AsyncView(
          isLoading: detail.isLoading && project == null,
          error: project == null ? detail.error : null,
          isEmpty: false,
          onRetry: detail.refresh,
          child: project == null
              ? const SizedBox.shrink()
              : TabBarView(
                  controller: _tabs,
                  children: <Widget>[
                    _OverviewTab(project: project),
                    _TasksTab(projectId: projectId),
                    RefreshIndicator(
                      onRefresh: detail.refresh,
                      child: ProjectPeople(
                        project: project,
                        members: detail.members,
                      ),
                    ),
                    ProjectDiscussionScreen(
                      projectId: projectId,
                      projectName: project.name,
                      embedded: true,
                    ),
                    _ActivityTab(projectId: projectId),
                  ],
                ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ProjectDetailProvider detail =
        context.watch<ProjectDetailProvider>();
    final TaskProvider tasks = context.watch<TaskProvider>();
    final UserProvider users = context.watch<UserProvider>();
    final TeamProvider teams = context.watch<TeamProvider>();

    final List<TaskModel> projectTasks = tasks.forProject(project.id);
    final int done = projectTasks.where((TaskModel t) => t.isCompleted).length;
    final int overdue = projectTasks.where((TaskModel t) => t.isOverdue).length;
    final bool late = isOverdue(project.endDate, project.status);

    return RefreshIndicator(
      onRefresh: detail.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: <Widget>[
          if (context.watch<ManagerProvider>().managerId != null &&
              isProjectClosed(project)) ...<Widget>[
            _ClosedBanner(project: project),
            const SizedBox(height: 16),
          ],
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
              if (late)
                const LabelChip(
                  text: 'Past due date',
                  color: Color(0xFFDC2626),
                  icon: Icons.schedule,
                ),
            ],
          ),
          if (project.description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(project.description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: StatCard(
                  label: 'Tasks',
                  value: projectTasks.length,
                  icon: Icons.checklist_outlined,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Completed',
                  value: done,
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Overdue',
                  value: overdue,
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: <Widget>[
                  ProgressRow(
                    label: 'Project progress',
                    value: project.progress,
                    total: 100,
                    color: theme.colorScheme.primary,
                  ),
                  const Divider(height: 24),
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
                    value: project.endDate == null
                        ? 'Not set'
                        : '${formatDate(project.endDate)} · ${dueLabel(project.endDate)}',
                  ),
                ],
              ),
            ),
          ),
          if (detail.progress.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            const SectionHeader(
              title: 'Backend progress report',
              subtitle: 'From the project progress endpoint',
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: detail.progress.entries
                      .map(
                        (MapEntry<String, dynamic> entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  humanizeChoice(entry.key),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                '${entry.value}',
                                style: theme.textTheme.labelLarge,
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TasksTab extends StatelessWidget {
  const _TasksTab({required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TaskProvider tasks = context.watch<TaskProvider>();
    final List<TaskModel> projectTasks = tasks.forProject(projectId);

    if (projectTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.task_alt, size: 40, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text('No tasks in this project yet',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Use the button below to add the first one.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: tasks.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: projectTasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext context, int index) {
          final TaskModel task = projectTasks[index];

          return TaskTile(
            task: task,
            showProject: false,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => TaskDetailScreen(taskId: task.id),
              ),
            ),
            onStatusTap: () => TaskActions.changeStatus(context, task),
            onAssignTap: () => TaskActions.reassign(context, task),
            onEdit: () => TaskActions.edit(context, task),
            onDelete: () => TaskActions.delete(context, task),
          );
        },
      ),
    );
  }
}

class _ActivityTab extends StatefulWidget {
  const _ActivityTab({required this.projectId});

  final int projectId;

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  List<ActivityLogModel> _logs = <ActivityLogModel>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // ActivityLog only links to a task, so the project feed is the union of
    // its tasks' logs.
    final Set<int> taskIds = context
        .read<TaskProvider>()
        .forProject(widget.projectId)
        .map((TaskModel t) => t.id)
        .toSet();

    if (taskIds.isEmpty) {
      setState(() {
        _logs = <ActivityLogModel>[];
        _loading = false;
      });

      return;
    }

    try {
      final List<ActivityLogModel> logs =
          await TaskService.getActivityLogs(taskIds: taskIds);

      if (!mounted) {
        return;
      }

      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AsyncView(
      isLoading: _loading,
      error: _error,
      isEmpty: _logs.isEmpty,
      onRetry: _load,
      emptyIcon: Icons.history,
      emptyTitle: 'No activity yet',
      emptyMessage:
          'Creating tasks, changing status and commenting all show up here.',
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: _logs.length,
          itemBuilder: (BuildContext context, int index) {
            final ActivityLogModel log = _logs[index];
            final TaskModel? task = context.read<TaskProvider>().byId(log.task);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ActivityRow(log: log, isLast: index == _logs.length - 1),
                if (task != null && index != _logs.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 38, bottom: 10),
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
              ],
            );
          },
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


/// Shown on a project nobody should still be editing.
class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: <Widget>[
            Icon(
              project.isArchived
                  ? Icons.inventory_2_outlined
                  : Icons.lock_outline,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Read-only', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    projectLockReason(project),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

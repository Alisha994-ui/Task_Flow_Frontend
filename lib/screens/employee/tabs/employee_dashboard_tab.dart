import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/task_constants.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../models/task_model.dart';
import '../../../models/task_stats_model.dart';
import '../../../models/time_log_model.dart';
import '../../../providers/manager_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/time_log_provider.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/admin/async_view.dart';
import '../../../widgets/manager/task_tile.dart';
import '../../manager/task_actions.dart';
import '../../manager/task_detail_screen.dart';

/// Answers one question: what should I work on now? Everything else sits
/// in the My tasks tab.
class EmployeeDashboardTab extends StatelessWidget {
  const EmployeeDashboardTab({super.key, required this.onSeeAllTasks});

  final VoidCallback onSeeAllTasks;

  @override
  Widget build(BuildContext context) {
    final TaskProvider tasks = context.watch<TaskProvider>();
    final ManagerProvider scope = context.watch<ManagerProvider>();
    final TimeLogProvider timer = context.watch<TimeLogProvider>();

    final TaskStatsModel stats = tasks.stats;
    final int open = stats.pending + stats.inProgress;

    return AsyncView(
      isLoading: tasks.isLoading && tasks.allTasks.isEmpty,
      error: tasks.allTasks.isEmpty ? tasks.error : null,
      isEmpty: false,
      onRetry: tasks.refresh,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait<void>(<Future<void>>[
            tasks.refresh(),
            timer.refresh(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            GreetingHeader(
              name: scope.managerName,
              subtitle: open == 0
                  ? 'You are all caught up.'
                  : '$open open ${open == 1 ? 'task' : 'tasks'}'
                      ' · ${formatMinutes(timer.minutesToday)} tracked today',
            ),
            const SizedBox(height: 20),
            const ActiveTimerCard(),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: MiniStat(
                    value: stats.pending,
                    label: 'To do',
                    color: TaskStatus.color(TaskStatus.todo),
                    onTap: onSeeAllTasks,
                  ),
                ),
                const SizedBox(width: 10),
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
              ],
            ),
            const SizedBox(height: 26),
            _WorkQueue(onSeeAllTasks: onSeeAllTasks),
          ],
        ),
      ),
    );
  }
}

/// One ordered queue instead of three lists: late work, then today, then
/// whatever is already started.
class _WorkQueue extends StatelessWidget {
  const _WorkQueue({required this.onSeeAllTasks});

  final VoidCallback onSeeAllTasks;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TaskProvider tasks = context.watch<TaskProvider>();

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final List<TaskModel> queue = <TaskModel>[];
    final Set<int> seen = <int>{};

    void add(Iterable<TaskModel> items) {
      for (final TaskModel task in items) {
        if (seen.add(task.id)) {
          queue.add(task);
        }
      }
    }

    add(tasks.overdueTasks);
    add(tasks.allTasks
        .where((TaskModel t) => !t.isCompleted && t.isDueOn(today)));
    add(tasks.allTasks
        .where((TaskModel t) => t.status == TaskStatus.inProgress));
    add(tasks.allTasks.where((TaskModel t) {
      if (t.isCompleted || t.dueDate == null) {
        return false;
      }

      final int? days = daysUntil(t.dueDate);

      return days != null && days > 0 && days <= 7;
    }));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'What to work on',
          subtitle: queue.isEmpty
              ? 'Nothing is due in the next week'
              : 'Late work first, then today',
          trailing: queue.length > 5
              ? TextButton(
                  onPressed: onSeeAllTasks,
                  child: const Text('See all'),
                )
              : null,
        ),
        const SizedBox(height: 12),
        if (queue.isEmpty)
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
                      'Nothing urgent. Pick something up from My tasks.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...queue.take(5).map(
                (TaskModel task) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TaskTile(
                    task: task,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => TaskDetailScreen(
                          taskId: task.id,
                          canManage: false,
                        ),
                      ),
                    ),
                    onStatusTap: task.isCompleted
                        ? null
                        : () => TaskActions.changeStatus(context, task),
                  ),
                ),
              ),
      ],
    );
  }
}

/// The running timer, or a quiet summary of time tracked.
class ActiveTimerCard extends StatefulWidget {
  const ActiveTimerCard({super.key});

  @override
  State<ActiveTimerCard> createState() => _ActiveTimerCardState();
}

class _ActiveTimerCardState extends State<ActiveTimerCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();

    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _stop() async {
    final TimeLogProvider timer = context.read<TimeLogProvider>();
    final String? problem = await timer.stop();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(problem ?? 'Timer stopped'),
          backgroundColor:
              problem == null ? null : Theme.of(context).colorScheme.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TimeLogProvider timer = context.watch<TimeLogProvider>();
    final TaskProvider tasks = context.watch<TaskProvider>();
    final ProjectProvider projects = context.watch<ProjectProvider>();
    final TimeLogModel? active = timer.activeLog;

    if (active == null) {
      return Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Icon(
            Icons.timer_outlined,
            color: theme.colorScheme.outline,
          ),
          title: const Text('No timer running'),
          subtitle: Text(
            '${formatMinutes(timer.minutesThisWeek)} tracked this week',
          ),
        ),
      );
    }

    final TaskModel? task = tasks.byId(active.task);

    return Card(
      color: theme.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: <Widget>[
            Icon(Icons.timer, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    formatMinutes(active.elapsedMinutes),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task?.title ?? 'Task #${active.task}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  if (task != null)
                    Text(
                      projects.byId(task.project)?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: timer.isBusy ? null : _stop,
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('Stop'),
            ),
          ],
        ),
      ),
    );
  }
}

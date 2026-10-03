import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/app_date_utils.dart';
import '../../models/task_model.dart';
import '../../models/time_log_model.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/time_log_provider.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../widgets/admin/async_view.dart';

/// Everything this user has tracked, newest first.
class EmployeeTimeLogsScreen extends StatelessWidget {
  const EmployeeTimeLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TimeLogProvider timer = context.watch<TimeLogProvider>();
    final TaskProvider tasks = context.watch<TaskProvider>();
    final ProjectProvider projects = context.watch<ProjectProvider>();

    final List<TimeLogModel> logs = timer.logs.toList()
      ..sort((TimeLogModel a, TimeLogModel b) {
        final DateTime aStart = a.startTime ?? DateTime(1970);
        final DateTime bStart = b.startTime ?? DateTime(1970);

        return bStart.compareTo(aStart);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time logs'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: timer.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AsyncView(
        isLoading: timer.isLoading && timer.logs.isEmpty,
        error: timer.logs.isEmpty ? timer.error : null,
        isEmpty: logs.isEmpty,
        onRetry: timer.refresh,
        emptyIcon: Icons.timer_outlined,
        emptyTitle: 'No time tracked yet',
        emptyMessage:
            'Start a timer from one of your tasks and it will show up here.',
        child: RefreshIndicator(
          onRefresh: timer.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TimeCard(
                      label: 'Today',
                      minutes: timer.minutesToday,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeCard(
                      label: 'This week',
                      minutes: timer.minutesThisWeek,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const SectionHeader(
                title: 'History',
                subtitle: 'Newest first',
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: logs.map((TimeLogModel log) {
                    final TaskModel? task = tasks.byId(log.task);
                    final bool isLast = log == logs.last;

                    return Column(
                      children: <Widget>[
                        ListTile(
                          leading: Icon(
                            log.isRunning
                                ? Icons.timer
                                : Icons.check_circle_outline,
                            color: log.isRunning
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                          title: Text(
                            task?.title ?? 'Task #${log.task}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${formatDate(log.startTime, fallback: 'Unknown date')}'
                            '${task == null ? '' : ' · ${projects.byId(task.project)?.name ?? ''}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: Text(
                            log.isRunning
                                ? 'running'
                                : formatMinutes(log.durationMinutes),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: log.isRunning
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                        if (!isLast) const Divider(height: 1, indent: 16),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.minutes,
    required this.color,
  });

  final String label;
  final int minutes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(
          children: <Widget>[
            Text(
              formatMinutes(minutes),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

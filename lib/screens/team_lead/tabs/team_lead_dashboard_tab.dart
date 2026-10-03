import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/task_constants.dart';
import '../../../models/task_model.dart';
import '../../../models/task_stats_model.dart';
import '../../../models/team_model.dart';
import '../../../models/time_log_model.dart';
import '../../../providers/manager_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/team_provider.dart';
import '../../../providers/time_log_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/admin/admin_widgets.dart';
import '../../../widgets/admin/async_view.dart';
import '../../../widgets/manager/task_tile.dart';
import '../../manager/task_actions.dart';
import '../../manager/task_detail_screen.dart';
import '../team_lead_member_detail_screen.dart';

/// Answers one question: what is my team doing right now, and what is
/// slipping? Team and project detail live in their own tabs.
class TeamLeadDashboardTab extends StatelessWidget {
  const TeamLeadDashboardTab({
    super.key,
    required this.onSeeAllTasks,
    required this.onSeeTeam,
  });

  final VoidCallback onSeeAllTasks;
  final VoidCallback onSeeTeam;

  @override
  Widget build(BuildContext context) {
    final TaskProvider tasks = context.watch<TaskProvider>();
    final TeamProvider teams = context.watch<TeamProvider>();
    final ManagerProvider scope = context.watch<ManagerProvider>();

    final List<TeamModel> myTeams = teams.allTeams
        .where((TeamModel t) => t.teamLead == scope.managerId)
        .toList();

    final int people = <int>{
      for (final TeamModel team in myTeams) ...team.members,
    }.length;

    final TaskStatsModel stats = tasks.stats;

    return AsyncView(
      isLoading: tasks.isLoading && tasks.allTasks.isEmpty,
      error: tasks.allTasks.isEmpty ? tasks.error : null,
      isEmpty: false,
      onRetry: tasks.refresh,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait<void>(<Future<void>>[
            tasks.refresh(),
            teams.refresh(),
            context.read<TimeLogProvider>().refresh(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            GreetingHeader(
              name: scope.managerName,
              subtitle: myTeams.isEmpty
                  ? 'You are not leading a team yet.'
                  : '$people ${people == 1 ? 'person' : 'people'}'
                      ' · ${stats.total} tasks',
            ),
            if (myTeams.isEmpty) ...<Widget>[
              const SizedBox(height: 24),
              const _NoTeamCard(),
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
                      value: tasks.unassignedTasks.length,
                      label: 'Unassigned',
                      color: const Color(0xFFD97706),
                      onTap: onSeeAllTasks,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const LiveTimersCard(),
              const SizedBox(height: 26),
              _NeedsAttention(onSeeAllTasks: onSeeAllTasks),
              const SizedBox(height: 26),
              _Workload(onSeeTeam: onSeeTeam),
            ],
          ],
        ),
      ),
    );
  }
}

/// Who on the team has a timer running. Ticks every 30 seconds.
///
/// Needs the backend change to TimeLogViewSet.get_queryset; without it a
/// lead only ever sees their own timer.
class LiveTimersCard extends StatefulWidget {
  const LiveTimersCard({super.key});

  @override
  State<LiveTimersCard> createState() => _LiveTimersCardState();
}

class _LiveTimersCardState extends State<LiveTimersCard> {
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TimeLogProvider timers = context.watch<TimeLogProvider>();
    final TaskProvider tasks = context.watch<TaskProvider>();
    final UserProvider users = context.watch<UserProvider>();

    final List<TimeLogModel> running = timers.runningLogs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Working right now',
          subtitle: running.isEmpty
              ? 'No timers running'
              : '${running.length} ${running.length == 1 ? 'person' : 'people'}'
                  ' tracking time',
        ),
        const SizedBox(height: 12),
        Card(
          child: running.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.timer_off_outlined,
                        size: 20,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nobody has a timer running.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: running.map((TimeLogModel log) {
                    final TaskModel? task = tasks.byId(log.task);
                    final bool isLast = log == running.last;
                    final bool isMe = log.user == timers.currentUserId;

                    return Column(
                      children: <Widget>[
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.timer,
                              size: 16,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Text(
                            isMe ? 'You' : users.nameFor(log.user),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          subtitle: Text(
                            task?.title ?? 'Task #${log.task}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            formatMinutes(log.elapsedMinutes),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: log.user == null
                              ? null
                              : () => Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          TeamLeadMemberDetailScreen(
                                        userId: log.user!,
                                      ),
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
    );
  }
}

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
          trailing: flagged.length > 3
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
                      'Your team is on time.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...flagged.take(3).map(
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

/// Open tasks per person, heaviest first - where to rebalance.
class _Workload extends StatelessWidget {
  const _Workload({required this.onSeeTeam});

  final VoidCallback onSeeTeam;

  @override
  Widget build(BuildContext context) {
    final TaskProvider tasks = context.watch<TaskProvider>();
    final UserProvider users = context.watch<UserProvider>();

    final List<MapEntry<int, int>> load = tasks.workload.entries
        .where((MapEntry<int, int> e) => e.key != -1)
        .toList()
      ..sort((MapEntry<int, int> a, MapEntry<int, int> b) =>
          b.value.compareTo(a.value));

    if (load.isEmpty) {
      return const SizedBox.shrink();
    }

    final int busiest = load.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Workload',
          subtitle: 'Open tasks per person',
          trailing: TextButton(
            onPressed: onSeeTeam,
            child: const Text('My team'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: load.take(5).map((MapEntry<int, int> entry) {
                return InkWell(
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          TeamLeadMemberDetailScreen(userId: entry.key),
                    ),
                  ),
                  child: ProgressRow(
                    label: users.nameFor(entry.key),
                    value: entry.value,
                    total: busiest,
                    color: const Color(0xFF2563EB),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoTeamCard extends StatelessWidget {
  const _NoTeamCard();

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
              Icons.groups_outlined,
              size: 26,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text('No team assigned yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'An admin needs to set you as the team lead on a team before '
              'this dashboard fills up.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

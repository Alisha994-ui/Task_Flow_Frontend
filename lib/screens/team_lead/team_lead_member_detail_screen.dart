import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/project_constants.dart';
import '../../core/utils/contact.dart';
import '../../core/constants/task_constants.dart';
import '../../models/task_model.dart';
import '../../models/time_log_model.dart';
import '../../models/user_model.dart';
import '../../providers/task_provider.dart';
import '../../providers/time_log_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../widgets/manager/task_tile.dart';
import '../manager/task_actions.dart';
import '../manager/task_detail_screen.dart';

/// What one team member is carrying, built from the task list already
/// loaded for this lead.
class TeamLeadMemberDetailScreen extends StatefulWidget {
  const TeamLeadMemberDetailScreen({super.key, required this.userId});

  final int userId;

  @override
  State<TeamLeadMemberDetailScreen> createState() =>
      _TeamLeadMemberDetailScreenState();
}

class _TeamLeadMemberDetailScreenState
    extends State<TeamLeadMemberDetailScreen> {
  bool _openOnly = true;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TaskProvider tasks = context.watch<TaskProvider>();
    final UserProvider users = context.watch<UserProvider>();
    final TimeLogProvider timers = context.watch<TimeLogProvider>();

    final UserModel? user = users.byId(widget.userId);
    final String name = users.nameFor(widget.userId);

    final List<TaskModel> theirs = tasks.allTasks
        .where((TaskModel t) => t.assignee == widget.userId)
        .toList();

    final int open = theirs.where((TaskModel t) => !t.isCompleted).length;
    final int done = theirs.where((TaskModel t) => t.isCompleted).length;
    final int overdue = theirs.where((TaskModel t) => t.isOverdue).length;

    final List<TaskModel> visible = _openOnly
        ? theirs.where((TaskModel t) => !t.isCompleted).toList()
        : theirs;

    visible.sort((TaskModel a, TaskModel b) {
      if (a.isOverdue != b.isOverdue) {
        return a.isOverdue ? -1 : 1;
      }

      final DateTime aDue = a.dueDate ?? DateTime(2999);
      final DateTime bDue = b.dueDate ?? DateTime(2999);

      return aDue.compareTo(bDue);
    });

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: RefreshIndicator(
        onRefresh: tasks.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            Row(
              children: <Widget>[
                UserAvatar(
                  name: name,
                  imageUrl: user?.profileImage,
                  radius: 26,
                  color: user == null ? null : UserRoles.color(user.role),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user == null
                            ? 'Team member'
                            : '${UserRoles.label(user.role)}'
                                '${user.email.isEmpty ? '' : ' · ${user.email}'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (user != null &&
                (user.email.isNotEmpty ||
                    (user.phone != null && user.phone!.isNotEmpty))) ...<Widget>[
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  if (user.email.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => openMail(
                          context,
                          user.email,
                          subject: 'TaskFlow',
                        ),
                        icon: const Icon(Icons.mail_outline, size: 18),
                        label: const Text('Email'),
                      ),
                    ),
                  if (user.email.isNotEmpty &&
                      user.phone != null &&
                      user.phone!.isNotEmpty)
                    const SizedBox(width: 10),
                  if (user.phone != null && user.phone!.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => openDialer(context, user.phone!),
                        icon: const Icon(Icons.phone_outlined, size: 18),
                        label: const Text('Call'),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: StatCard(
                    label: 'Open',
                    value: open,
                    icon: Icons.pending_actions_outlined,
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
            const SizedBox(height: 16),
            _TimeTracked(
              totalMinutes: timers.minutesForUser(widget.userId),
              todayMinutes: timers.minutesTodayForUser(widget.userId),
              running: timers
                  .logsForUser(widget.userId)
                  .where((TimeLogModel l) => l.isRunning)
                  .isNotEmpty,
              logCount: timers.logsForUser(widget.userId).length,
            ),
            const SizedBox(height: 20),
            if (theirs.isNotEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Column(
                    children: TaskStatus.all
                        .where((String status) =>
                            theirs.any((TaskModel t) => t.status == status))
                        .map(
                          (String status) => ProgressRow(
                            label: TaskStatus.label(status),
                            value: theirs
                                .where((TaskModel t) => t.status == status)
                                .length,
                            total: theirs.length,
                            color: TaskStatus.color(status),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: SectionHeader(
                    title: 'Tasks',
                    subtitle: '${visible.length} shown',
                  ),
                ),
                FilterChip(
                  label: const Text('Open only'),
                  selected: _openOnly,
                  onSelected: (bool value) =>
                      setState(() => _openOnly = value),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (visible.isEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _openOnly
                        ? 'Nothing open right now.'
                        : 'No tasks assigned to this person yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...visible.map(
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
                    onEdit: () => TaskActions.edit(context, task),
                    onDelete: () => TaskActions.delete(context, task),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Time this person has tracked. Empty until the backend lets a team lead
/// read other people's TimeLog rows.
class _TimeTracked extends StatelessWidget {
  const _TimeTracked({
    required this.totalMinutes,
    required this.todayMinutes,
    required this.running,
    required this.logCount,
  });

  final int totalMinutes;
  final int todayMinutes;
  final bool running;
  final int logCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (logCount == 0) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(
            Icons.timer_off_outlined,
            color: theme.colorScheme.outline,
          ),
          title: const Text('No time tracked'),
          subtitle: Text(
            'This person has not started a timer yet.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      color: running ? theme.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: <Widget>[
            Icon(
              running ? Icons.timer : Icons.timer_outlined,
              color: running
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    running ? 'Timer running now' : 'Time tracked',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: running
                          ? theme.colorScheme.onPrimaryContainer
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatMinutes(todayMinutes)} today · '
                    '${formatMinutes(totalMinutes)} total · '
                    '$logCount ${logCount == 1 ? 'entry' : 'entries'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: running
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
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

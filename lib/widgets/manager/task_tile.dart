import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/project_constants.dart';
import '../../core/constants/task_constants.dart';
import '../../core/utils/app_date_utils.dart';
import '../../models/task_model.dart';
import '../../models/time_log_model.dart';
import '../../models/user_model.dart';
import '../../providers/project_provider.dart';
import '../../providers/time_log_provider.dart';
import '../../providers/user_provider.dart';
import '../admin/admin_widgets.dart';

/// One task row. Used on the Tasks tab, the calendar and project details.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onTap,
    this.onStatusTap,
    this.onAssignTap,
    this.onEdit,
    this.onDelete,
    this.showProject = true,
  });

  final TaskModel task;
  final VoidCallback onTap;
  final VoidCallback? onStatusTap;
  final VoidCallback? onAssignTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final UserProvider users = context.watch<UserProvider>();
    final ProjectProvider projects = context.watch<ProjectProvider>();
    final Color statusColor = TaskStatus.color(task.status);
    final UserModel? assignee = users.byId(task.assignee);

    // Zero when nobody has tracked time, or when the signed-in role is not
    // allowed to see this task's logs - the chip just stays hidden.
    final int loggedMinutes =
        context.watch<TimeLogProvider>().minutesOnTask(task.id);

    // For finished work, how long it took start to finish. created_at to
    // updated_at is the closest the API gives us to a completion stamp.
    final String? tookToFinish = task.isCompleted
        ? completionSpan(task.createdAt, task.updatedAt)
        : null;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconButton(
                tooltip: onStatusTap == null
                    ? TaskStatus.label(task.status)
                    : 'Change status',
                onPressed: onStatusTap,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  TaskStatus.icon(task.status),
                  // A locked status still shows its real colour - it is
                  // settled, not unavailable.
                  color: statusColor,
                  size: 22,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration:
                            task.isCompleted ? TextDecoration.lineThrough : null,
                        color: task.isCompleted
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    if (showProject) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        task.projectName ??
                            projects.byId(task.project)?.name ??
                            'Project #${task.project}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        LabelChip(
                          text: TaskStatus.label(task.status),
                          color: statusColor,
                        ),
                        LabelChip(
                          text: TaskPriority.label(task.priority),
                          color: TaskPriority.color(task.priority),
                          icon: Icons.flag_outlined,
                        ),
                        if (task.dueDate != null)
                          LabelChip(
                            text: dueLabel(task.dueDate, closed: task.isCompleted),
                            color: task.isOverdue
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF6B7280),
                            icon: Icons.event_outlined,
                          ),
                        if (tookToFinish != null)
                          LabelChip(
                            text: 'Done in $tookToFinish',
                            color: const Color(0xFF059669),
                            icon: Icons.check_circle_outline,
                          ),
                        if (loggedMinutes > 0)
                          LabelChip(
                            text: formatMinutes(loggedMinutes),
                            color: const Color(0xFF0D9488),
                            icon: Icons.timer_outlined,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        GestureDetector(
                          onTap: onAssignTap,
                          child: Row(
                            children: <Widget>[
                              if (assignee == null)
                                Icon(
                                  Icons.person_off_outlined,
                                  size: 15,
                                  color: theme.colorScheme.outline,
                                )
                              else
                                UserAvatar(
                                  name: assignee.fullName,
                                  imageUrl: assignee.profileImage,
                                  radius: 9,
                                  color: UserRoles.color(assignee.role),
                                ),
                              const SizedBox(width: 6),
                              Text(
                                assignee?.fullName ?? 'Unassigned',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: assignee == null
                                      ? theme.colorScheme.outline
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (task.progress > 0 && !task.isCompleted)
                          Text(
                            '${task.progress}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onEdit != null ||
                  onDelete != null ||
                  onAssignTap != null ||
                  onStatusTap != null)
                PopupMenuButton<String>(
                  tooltip: 'Task actions',
                  onSelected: (String action) {
                    switch (action) {
                      case 'status':
                        onStatusTap?.call();
                        break;
                      case 'assign':
                        onAssignTap?.call();
                        break;
                      case 'edit':
                        onEdit?.call();
                        break;
                      case 'delete':
                        onDelete?.call();
                        break;
                    }
                  },
                  // Only offer actions this caller actually wired up - a
                  // role with no onDelete must not even see a Delete entry
                  // it can silently tap with nothing happening.
                  itemBuilder: (_) => <PopupMenuEntry<String>>[
                    if (onStatusTap != null)
                      const PopupMenuItem<String>(
                        value: 'status',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.swap_horiz),
                          title: Text('Change status'),
                        ),
                      ),
                    if (onAssignTap != null)
                      const PopupMenuItem<String>(
                        value: 'assign',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.person_add_alt),
                          title: Text('Reassign'),
                        ),
                      ),
                    if (onEdit != null)
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                        ),
                      ),
                    if (onDelete != null) ...<PopupMenuEntry<String>>[
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            'Delete',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet that returns the chosen status, or null if dismissed.
Future<String?> pickTaskStatus(BuildContext context, String current) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Move task to',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
            ...TaskStatus.all.map(
              (String status) => ListTile(
                leading: Icon(
                  TaskStatus.icon(status),
                  color: TaskStatus.color(status),
                ),
                title: Text(TaskStatus.label(status)),
                trailing: status == current
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(status),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Bottom sheet for picking an assignee.
///
/// Returns the chosen user id, or -1 to unassign, or null if dismissed.
Future<int?> pickAssignee(
  BuildContext context, {
  required List<UserModel> candidates,
  int? current,
  // Shown above the list only when the caller had to widen it past the
  // project's own team (e.g. the team has nobody in it yet) - otherwise
  // "everyone" silently appearing here reads as the picker ignoring the
  // team rather than a deliberate fallback.
  String? scopeNote,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      final ThemeData theme = Theme.of(sheetContext);

      return SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.6,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Assign to',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (scopeNote != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      scopeNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_off_outlined, size: 18),
                      ),
                      title: const Text('Unassigned'),
                      trailing:
                          current == null ? const Icon(Icons.check, size: 18) : null,
                      onTap: () => Navigator.of(sheetContext).pop(-1),
                    ),
                    if (candidates.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No people found for this project. Add members to '
                          'the project or its team first.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      ...candidates.map(
                        (UserModel user) => ListTile(
                          leading: UserAvatar(
                            name: user.fullName,
                            imageUrl: user.profileImage,
                            radius: 18,
                            color: UserRoles.color(user.role),
                          ),
                          title: Text(user.fullName),
                          subtitle: Text(UserRoles.label(user.role)),
                          trailing: user.id == current
                              ? const Icon(Icons.check, size: 18)
                              : null,
                          onTap: () => Navigator.of(sheetContext).pop(user.id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

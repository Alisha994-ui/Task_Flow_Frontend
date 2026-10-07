import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/task_constants.dart';
import '../../core/utils/app_date_utils.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/user_provider.dart';
import '../../screens/manager/task_actions.dart';
import '../../screens/manager/task_detail_screen.dart';
import '../admin/admin_widgets.dart';

/// A column per status, cards dragged between them.
///
/// Long press to pick a card up - a plain drag would fight the
/// horizontal scroll, and on a phone that makes the board unusable.
class TaskBoard extends StatefulWidget {
  const TaskBoard({
    super.key,
    this.canManage = true,
    this.showProject = true,
  });

  /// False for an employee: they may still move their own tasks, but a
  /// completed one stops moving.
  final bool canManage;

  final bool showProject;

  @override
  State<TaskBoard> createState() => _TaskBoardState();
}

class _TaskBoardState extends State<TaskBoard> {
  /// The status currently under the finger, so the column can light up.
  String? _hovering;

  /// The task being moved, so its card can be dimmed where it sits.
  int? _dragging;

  Future<void> _move(TaskModel task, String status) async {
    if (task.status == status) {
      return;
    }

    final TaskProvider tasks = context.read<TaskProvider>();

    // Same rules as everywhere else: a closed project refuses edits,
    // and an employee cannot reopen their own completed task.
    await TaskActions.changeStatus(
      context,
      task,
      toStatus: status,
    );

    if (!mounted) {
      return;
    }

    if (tasks.error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(tasks.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TaskProvider tasks = context.watch<TaskProvider>();
    final Map<String, List<TaskModel>> columns = tasks.board;

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: TaskStatus.all.length,
      itemBuilder: (BuildContext context, int index) {
        final String status = TaskStatus.all[index];
        final List<TaskModel> items = columns[status] ?? <TaskModel>[];

        return _Column(
          status: status,
          tasks: items,
          hovering: _hovering == status,
          draggingId: _dragging,
          canManage: widget.canManage,
          showProject: widget.showProject,
          onWillAccept: (String? s) => setState(() => _hovering = status),
          onLeave: () => setState(() => _hovering = null),
          onAccept: (TaskModel task) {
            setState(() {
              _hovering = null;
              _dragging = null;
            });

            _move(task, status);
          },
          onDragStart: (int id) => setState(() => _dragging = id),
          onDragEnd: () => setState(() {
            _dragging = null;
            _hovering = null;
          }),
        );
      },
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.status,
    required this.tasks,
    required this.hovering,
    required this.draggingId,
    required this.canManage,
    required this.showProject,
    required this.onWillAccept,
    required this.onLeave,
    required this.onAccept,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final String status;
  final List<TaskModel> tasks;
  final bool hovering;
  final int? draggingId;
  final bool canManage;
  final bool showProject;
  final void Function(String?) onWillAccept;
  final VoidCallback onLeave;
  final void Function(TaskModel) onAccept;
  final void Function(int) onDragStart;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color colour = TaskStatus.color(status);

    return Container(
      width: 272,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: hovering
            ? colour.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hovering ? colour : theme.colorScheme.outlineVariant,
          width: hovering ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colour,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    TaskStatus.label(status),
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colour.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colour,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<TaskModel>(
              onWillAcceptWithDetails: (DragTargetDetails<TaskModel> details) {
                onWillAccept(status);

                return details.data.status != status;
              },
              onLeave: (_) => onLeave(),
              onAcceptWithDetails:
                  (DragTargetDetails<TaskModel> details) =>
                      onAccept(details.data),
              builder: (
                BuildContext context,
                List<TaskModel?> candidate,
                List<dynamic> rejected,
              ) {
                if (tasks.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        hovering ? 'Drop here' : 'Nothing here',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: hovering
                              ? colour
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: hovering ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                  itemCount: tasks.length,
                  itemBuilder: (BuildContext context, int index) {
                    final TaskModel task = tasks[index];

                    return _DraggableCard(
                      task: task,
                      dimmed: draggingId == task.id,
                      canManage: canManage,
                      showProject: showProject,
                      onDragStart: () => onDragStart(task.id),
                      onDragEnd: onDragEnd,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableCard extends StatelessWidget {
  const _DraggableCard({
    required this.task,
    required this.dimmed,
    required this.canManage,
    required this.showProject,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final TaskModel task;
  final bool dimmed;
  final bool canManage;
  final bool showProject;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final Widget card = _BoardCard(
      task: task,
      canManage: canManage,
      showProject: showProject,
    );

    // An employee's finished task is settled - nothing to drag.
    final bool locked = !canManage && task.isCompleted;

    if (locked) {
      return Opacity(opacity: 0.7, child: card);
    }

    return LongPressDraggable<TaskModel>(
      data: task,
      onDragStarted: onDragStart,
      onDraggableCanceled: (_, _) => onDragEnd(),
      onDragCompleted: onDragEnd,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 248,
          child: Transform.rotate(
            angle: 0.02,
            child: _BoardCard(
              task: task,
              canManage: canManage,
              showProject: showProject,
              raised: true,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: Opacity(opacity: dimmed ? 0.35 : 1, child: card),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.task,
    required this.canManage,
    required this.showProject,
    this.raised = false,
  });

  final TaskModel task;
  final bool canManage;
  final bool showProject;

  /// True for the floating copy under the finger - no controls on that.
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // An employee's finished task is settled: it neither drags nor
    // offers the status control.
    final bool locked = !canManage && task.isCompleted;
    final UserProvider users = context.watch<UserProvider>();
    final ProjectProvider projects = context.watch<ProjectProvider>();
    final UserModel? assignee = users.byId(task.assignee);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surface,
        elevation: raised ? 8 : 0,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => TaskDetailScreen(
                taskId: task.id,
                canManage: canManage,
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  task.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (showProject) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    task.projectName ??
                        projects.byId(task.project)?.name ??
                        'Project #${task.project}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
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
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    if (assignee == null)
                      Icon(
                        Icons.person_off_outlined,
                        size: 14,
                        color: theme.colorScheme.outline,
                      )
                    else
                      UserAvatar(
                        name: assignee.fullName,
                        imageUrl: assignee.profileImage,
                        radius: 9,
                      ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        assignee?.fullName ?? 'Unassigned',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    // The second way to move a card: tap the status,
                    // pick one, and it lands in that column. Dragging is
                    // quicker once you know it; tapping is what people
                    // try first.
                    if (!raised && !locked)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () =>
                            TaskActions.changeStatus(context, task),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                TaskStatus.icon(task.status),
                                size: 15,
                                color: TaskStatus.color(task.status),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.unfold_more,
                                size: 13,
                                color: theme.colorScheme.outline,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

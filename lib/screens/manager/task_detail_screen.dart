import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/task_constants.dart';
import '../../core/utils/app_date_utils.dart';
import '../../models/activity_log_model.dart';
import '../../models/attachment_model.dart';
import '../../models/comment_model.dart';
import '../../models/subtask_model.dart';
import '../../models/task_model.dart';
import '../../models/time_log_model.dart';
import '../../models/team_model.dart';
import '../../models/user_model.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_detail_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/time_log_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../widgets/admin/async_view.dart';
import '../../widgets/manager/task_tile.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({
    super.key,
    required this.taskId,
    this.canManage = true,
  });

  final int taskId;

  /// False for an employee: they may change the status of their own task but
  /// not edit it or hand it to someone else.
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TaskDetailProvider>(
      create: (_) => TaskDetailProvider(taskId)..load(),
      child: _TaskDetailView(canManage: canManage),
    );
  }
}

class _TaskDetailView extends StatelessWidget {
  const _TaskDetailView({required this.canManage});

  final bool canManage;

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

  Future<void> _changeStatus(BuildContext context, TaskModel task) async {
    // canManage is false only for the employee panel. Once they have
    // marked their task complete, reopening it is somebody else's call.
    if (!canManage && task.isCompleted) {
      _snack(
        context,
        'This task is complete. Ask your team lead or manager to reopen it.',
        isError: true,
      );

      return;
    }

    final TaskDetailProvider detail = context.read<TaskDetailProvider>();
    final TaskProvider tasks = context.read<TaskProvider>();

    final String? status = await pickTaskStatus(context, task.status);

    if (status == null || status == task.status) {
      return;
    }

    final bool ok = await tasks.setStatus(task.id, status);

    if (!context.mounted) {
      return;
    }

    if (ok) {
      final TaskModel? updated = tasks.byId(task.id);

      if (updated != null) {
        detail.setTask(updated);
      }

      await detail.reloadActivity();
    } else {
      _snack(context, tasks.error ?? 'Could not change the status',
          isError: true);
    }
  }

  Future<void> _reassign(BuildContext context, TaskModel task) async {
    final TaskDetailProvider detail = context.read<TaskDetailProvider>();
    final TaskProvider tasks = context.read<TaskProvider>();
    final UserProvider users = context.read<UserProvider>();
    final TeamProvider teams = context.read<TeamProvider>();
    final ProjectProvider projects = context.read<ProjectProvider>();

    final TeamModel? team = teams.byId(projects.byId(task.project)?.team);

    final List<UserModel> candidates = team == null || team.members.isEmpty
        ? users.allUsers
        : users.allUsers
            .where((UserModel u) =>
                team.members.contains(u.id) || team.teamLead == u.id)
            .toList();

    final int? picked = await pickAssignee(
      context,
      candidates: candidates.isEmpty ? users.allUsers : candidates,
      current: task.assignee,
    );

    if (picked == null) {
      return;
    }

    final int? userId = picked == -1 ? null : picked;
    final bool ok = await tasks.assignTo(task.id, userId);

    if (!context.mounted) {
      return;
    }

    if (ok) {
      final TaskModel? updated = tasks.byId(task.id);

      if (updated != null) {
        detail.setTask(updated);
      }

      _snack(context, userId == null ? 'Task unassigned' : 'Task reassigned');

      await detail.reloadActivity();
    } else {
      _snack(context, tasks.error ?? 'Could not reassign the task',
          isError: true);
    }
  }

  Future<void> _edit(BuildContext context, TaskModel task) async {
    final TaskDetailProvider detail = context.read<TaskDetailProvider>();

    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => TaskFormScreen(task: task)),
    );

    if (saved == true) {
      await detail.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final TaskDetailProvider detail = context.watch<TaskDetailProvider>();
    final TaskModel? task = detail.task;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Task'),
          actions: <Widget>[
            if (task != null && canManage)
              IconButton(
                tooltip: 'Edit task',
                onPressed: () => _edit(context, task),
                icon: const Icon(Icons.edit_outlined),
              ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: detail.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Overview'),
              Tab(text: 'Comments'),
              Tab(text: 'Activity'),
            ],
          ),
        ),
        body: AsyncView(
          isLoading: detail.isLoading && task == null,
          error: task == null ? detail.error : null,
          isEmpty: false,
          onRetry: detail.refresh,
          child: task == null
              ? const SizedBox.shrink()
              : TabBarView(
                  children: <Widget>[
                    _OverviewTab(
                      task: task,
                      canManage: canManage,
                      onStatusTap: () => _changeStatus(context, task),
                      onAssignTap:
                          canManage ? () => _reassign(context, task) : null,
                    ),
                    const _CommentsTab(),
                    const _ActivityTab(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.task,
    required this.canManage,
    required this.onStatusTap,
    this.onAssignTap,
  });

  final TaskModel task;
  final bool canManage;
  final VoidCallback onStatusTap;
  final VoidCallback? onAssignTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TaskDetailProvider detail = context.watch<TaskDetailProvider>();
    final UserProvider users = context.watch<UserProvider>();
    final ProjectProvider projects = context.watch<ProjectProvider>();
    final TimeLogProvider timers = context.watch<TimeLogProvider>();
    final int loggedMinutes = timers.minutesOnTask(task.id);

    // For an employee a finished task is closed for good: no status
    // change, no new subtasks, no new files. Comments stay open so they
    // can still ask a question.
    final bool locked = !canManage && task.isCompleted;
    final bool timerRunning =
        timers.runningLogs.any((TimeLogModel l) => l.task == task.id);

    return RefreshIndicator(
      onRefresh: detail.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Text(
            task.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            projects.byId(task.project)?.name ?? 'Project #${task.project}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (!canManage && task.isCompleted)
                LabelChip(
                  text: TaskStatus.label(task.status),
                  color: TaskStatus.color(task.status),
                  icon: TaskStatus.icon(task.status),
                  dense: false,
                )
              else
                ActionChip(
                  avatar: Icon(
                    TaskStatus.icon(task.status),
                    size: 16,
                    color: TaskStatus.color(task.status),
                  ),
                  label: Text(TaskStatus.label(task.status)),
                  onPressed: onStatusTap,
                ),
              if (onAssignTap != null)
                ActionChip(
                  avatar: const Icon(Icons.person_outline, size: 16),
                  label: Text(
                    task.assignee == null
                        ? 'Unassigned'
                        : users.nameFor(task.assignee),
                  ),
                  onPressed: onAssignTap,
                )
              else
                LabelChip(
                  text: task.assignee == null
                      ? 'Unassigned'
                      : users.nameFor(task.assignee),
                  color: const Color(0xFF6B7280),
                  icon: Icons.person_outline,
                  dense: false,
                ),
              LabelChip(
                text: TaskPriority.label(task.priority),
                color: TaskPriority.color(task.priority),
                icon: Icons.flag_outlined,
                dense: false,
              ),
              if (task.isOverdue)
                const LabelChip(
                  text: 'Overdue',
                  color: Color(0xFFDC2626),
                  icon: Icons.schedule,
                  dense: false,
                ),
            ],
          ),
          if (task.description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Text(task.description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: <Widget>[
                  ProgressRow(
                    label: 'Task progress',
                    value: task.progress,
                    total: 100,
                    color: TaskStatus.color(task.status),
                  ),
                  const Divider(height: 24),
                  _InfoRow(
                    icon: Icons.play_circle_outline,
                    label: 'Starts',
                    value: formatDate(task.startDate),
                  ),
                  _InfoRow(
                    icon: Icons.event_outlined,
                    label: 'Due',
                    value: task.dueDate == null
                        ? 'Not set'
                        : '${formatDate(task.dueDate)} · ${dueLabel(task.dueDate)}',
                  ),
                  _InfoRow(
                    icon: Icons.person_add_alt,
                    label: 'Created by',
                    value: users.nameFor(task.creator, fallback: 'Unknown'),
                  ),
                  _InfoRow(
                    icon: Icons.update,
                    label: 'Updated',
                    value: formatDate(task.updatedAt, fallback: 'Unknown'),
                  ),
                  if (task.isCompleted &&
                      completionSpan(task.createdAt, task.updatedAt) != null)
                    _InfoRow(
                      icon: Icons.check_circle_outline,
                      label: 'Completed in',
                      value:
                          '${completionSpan(task.createdAt, task.updatedAt)}'
                          ' from creation',
                    ),
                  _InfoRow(
                    icon: timerRunning ? Icons.timer : Icons.timer_outlined,
                    label: 'Time spent',
                    value: loggedMinutes == 0
                        ? 'Nothing tracked yet'
                        : '${formatMinutes(loggedMinutes)}'
                            '${timerRunning ? ' · timer running' : ''}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _SubtaskSection(locked: locked),
          const SizedBox(height: 22),
          _AttachmentSection(locked: locked),
          if (locked) ...<Widget>[
            const SizedBox(height: 18),
            _LockedNote(),
          ],
        ],
      ),
    );
  }
}

class _SubtaskSection extends StatefulWidget {
  const _SubtaskSection({required this.locked});

  final bool locked;

  @override
  State<_SubtaskSection> createState() => _SubtaskSectionState();
}

class _SubtaskSectionState extends State<_SubtaskSection> {
  final TextEditingController _controller = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String title = _controller.text.trim();

    if (title.isEmpty) {
      return;
    }

    final TaskDetailProvider detail = context.read<TaskDetailProvider>();
    final bool ok = await detail.addSubtask(title);

    if (!mounted) {
      return;
    }

    if (ok) {
      _controller.clear();
      setState(() => _adding = false);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(detail.error ?? 'Could not add the subtask'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TaskDetailProvider detail = context.watch<TaskDetailProvider>();
    final List<SubtaskModel> subtasks = detail.subtasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Subtasks',
          subtitle: subtasks.isEmpty
              ? (widget.locked
                  ? 'None were added'
                  : 'Break the work into smaller steps')
              : '${detail.doneSubtasks} of ${subtasks.length} done',
          trailing: widget.locked
              ? null
              : IconButton(
                  tooltip: 'Add subtask',
                  onPressed: () => setState(() => _adding = !_adding),
                  icon: Icon(_adding ? Icons.close : Icons.add),
                ),
        ),
        if (_adding && !widget.locked) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'What needs doing?',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: detail.isBusy ? null : _submit,
                child: const Text('Add'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        if (subtasks.isEmpty)
          Text(
            'No subtasks yet.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: subtasks.map((SubtaskModel subtask) {
                return CheckboxListTile(
                  value: subtask.isDone,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: detail.isBusy || widget.locked
                      ? null
                      : (_) => detail.toggleSubtask(subtask),
                  title: Text(
                    subtask.title,
                    style: TextStyle(
                      decoration:
                          subtask.isDone ? TextDecoration.lineThrough : null,
                      color: subtask.isDone
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  secondary: widget.locked
                      ? null
                      : IconButton(
                          tooltip: 'Delete subtask',
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: theme.colorScheme.outline,
                          ),
                          onPressed: detail.isBusy
                              ? null
                              : () => detail.deleteSubtask(subtask.id),
                        ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _CommentsTab extends StatefulWidget {
  const _CommentsTab();

  @override
  State<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<_CommentsTab> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _controller.text.trim();

    if (text.isEmpty) {
      return;
    }

    final TaskDetailProvider detail = context.read<TaskDetailProvider>();
    final bool ok = await detail.addComment(text);

    if (!mounted) {
      return;
    }

    if (ok) {
      _controller.clear();
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(detail.error ?? 'Could not post the comment'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TaskDetailProvider detail = context.watch<TaskDetailProvider>();
    final List<CommentModel> comments = detail.comments;

    return Column(
      children: <Widget>[
        Expanded(
          child: comments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No comments yet. Start the conversation below.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: comments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final CommentModel comment = comments[index];

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        UserAvatar(name: comment.userName, radius: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      comment.userName.isEmpty
                                          ? 'Someone'
                                          : comment.userName,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatDate(comment.createdAt,
                                        fallback: 'Just now'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(comment.text,
                                  style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Write a comment',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: detail.isBusy ? null : _send,
                  icon: const Icon(Icons.send, size: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TaskDetailProvider detail = context.watch<TaskDetailProvider>();
    final List<ActivityLogModel> logs = detail.activity;

    if (logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Nothing has happened on this task yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: detail.reloadActivity,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: logs.length,
        itemBuilder: (BuildContext context, int index) {
          final ActivityLogModel log = logs[index];
          final bool isLast = index == logs.length - 1;

          return ActivityRow(log: log, isLast: isLast);
        },
      ),
    );
  }
}

/// Timeline row, shared with the project activity tab.
class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.log, required this.isLast});

  final ActivityLogModel log;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = ActivityAction.color(log.action);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  ActivityAction.icon(log.action),
                  size: 14,
                  color: color,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    log.description.isEmpty
                        ? ActivityAction.label(log.action)
                        : log.description,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${log.userName.isEmpty ? 'System' : log.userName} · '
                    '${formatDate(log.createdAt, fallback: 'Recently')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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


/// Files attached to this task. Upload uses multipart, so it goes through
/// ApiClient.postMultipart rather than the JSON helpers.
class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({required this.locked});

  final bool locked;

  IconData _iconFor(AttachmentModel file) {
    if (file.isImage) {
      return Icons.image_outlined;
    }

    switch (file.extension) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_outlined;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_outlined;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.movie_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

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

  Future<void> _pickAndUpload(BuildContext context) async {
    final TaskDetailProvider detail = context.read<TaskDetailProvider>();

    // file_picker 13.x returns the files directly, not a result object.
    final List<PlatformFile> picked = await FilePicker.pickFiles();

    if (picked.isEmpty) {
      return;
    }

    final String? path = picked.first.path;

    if (path == null) {
      return;
    }

    final String? problem = await detail.uploadAttachment(path);

    if (!context.mounted) {
      return;
    }

    _snack(
      context,
      problem ?? 'File uploaded',
      isError: problem != null,
    );
  }

  Future<void> _open(BuildContext context, AttachmentModel file) async {
    final Uri uri = Uri.parse(file.url);
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      _snack(context, 'Could not open this file', isError: true);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AttachmentModel file,
  ) async {
    final TaskDetailProvider detail = context.read<TaskDetailProvider>();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Remove this file?'),
          content: Text('"${file.fileName}" will be deleted for everyone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep it'),
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

    if (confirmed != true || !context.mounted) {
      return;
    }

    final bool ok = await detail.deleteAttachment(file.id);

    if (!context.mounted) {
      return;
    }

    _snack(
      context,
      ok ? 'File removed' : (detail.error ?? 'Could not remove the file'),
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TaskDetailProvider detail = context.watch<TaskDetailProvider>();
    final List<AttachmentModel> files = detail.attachments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Files',
          subtitle: files.isEmpty
              ? (locked ? 'None were attached' : 'Nothing attached yet')
              : '${files.length} ${files.length == 1 ? 'file' : 'files'}',
          trailing: locked
              ? null
              : detail.isUploading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Attach a file',
                  onPressed: () => _pickAndUpload(context),
                  icon: const Icon(Icons.attach_file),
                ),
        ),
        const SizedBox(height: 8),
        if (files.isEmpty && locked)
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                Icons.folder_off_outlined,
                color: theme.colorScheme.outline,
              ),
              title: const Text('No files on this task'),
              subtitle: Text(
                'Files cannot be added once the task is complete.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          )
        else if (files.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                Icons.cloud_upload_outlined,
                color: theme.colorScheme.outline,
              ),
              title: const Text('Attach a file'),
              subtitle: Text(
                'Specs, screenshots, anything the task needs.',
                style: theme.textTheme.bodySmall,
              ),
              onTap: detail.isUploading ? null : () => _pickAndUpload(context),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: files.map((AttachmentModel file) {
                final bool isLast = file == files.last;

                return Column(
                  children: <Widget>[
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _iconFor(file),
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        file.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      subtitle: Text(
                        '${file.uploadedByName.isEmpty ? 'Someone' : file.uploadedByName}'
                        ' · ${formatDate(file.createdAt, fallback: 'recently')}',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: locked
                          ? null
                          : IconButton(
                              tooltip: 'Remove',
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: theme.colorScheme.outline,
                              ),
                              onPressed: detail.isBusy
                                  ? null
                                  : () => _confirmDelete(context, file),
                            ),
                      onTap: () => _open(context, file),
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

/// Says once, at the bottom of a finished task, why the controls are
/// gone - instead of leaving the person to work it out.
class _LockedNote extends StatelessWidget {
  const _LockedNote();

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
              Icons.lock_outline,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Task complete', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Status, subtasks and files are locked. You can still '
                    'comment. Ask your team lead or manager to reopen it.',
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

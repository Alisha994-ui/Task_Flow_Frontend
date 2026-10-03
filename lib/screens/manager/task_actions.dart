import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/project_rules.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/team_model.dart';
import '../../models/user_model.dart';
import '../../providers/manager_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/team_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/manager/task_tile.dart';
import 'task_form_screen.dart';

/// Quick actions shared by every screen that lists tasks, so the Tasks tab,
/// the calendar and the project view all behave the same way.
class TaskActions {
  const TaskActions._();

  static void _snack(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
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


  /// True when this task sits in a finished, cancelled or archived
  /// project and the signed-in person is not an admin.
  ///
  /// An admin has no manager scope, so managerId is null for them and
  /// nothing is locked.
  static bool _isLocked(BuildContext context, int projectId) {
    if (context.read<ManagerProvider>().managerId == null) {
      return false;
    }

    return isProjectClosed(context.read<ProjectProvider>().byId(projectId));
  }

  /// True when the signed-in person may only act on their own task -
  /// the employee panel sets this endpoint, nobody else does.
  static bool _isEmployee(BuildContext context) {
    return context.read<TaskProvider>().statusEndpoint ==
        TaskStatusEndpoint.assigneeAction;
  }

  /// Finishing a task is a one-way door for an employee. Reopening it is
  /// a decision for whoever owns the work.
  static bool _completedAndLocked(BuildContext context, TaskModel task) {
    if (!task.isCompleted || !_isEmployee(context)) {
      return false;
    }

    _snack(
      context,
      'This task is complete. Ask your team lead or manager to reopen it.',
      isError: true,
    );

    return true;
  }

  static bool _blocked(BuildContext context, int projectId) {
    if (!_isLocked(context, projectId)) {
      return false;
    }

    final ProjectModel? project =
        context.read<ProjectProvider>().byId(projectId);

    _snack(context, projectLockReason(project), isError: true);

    return true;
  }

  static Future<void> changeStatus(BuildContext context, TaskModel task) async {
    if (_blocked(context, task.project)) {
      return;
    }

    if (_completedAndLocked(context, task)) {
      return;
    }

    final TaskProvider tasks = context.read<TaskProvider>();
    final String? status = await pickTaskStatus(context, task.status);

    if (status == null || status == task.status) {
      return;
    }

    final bool ok = await tasks.setStatus(task.id, status);

    if (!context.mounted) {
      return;
    }

    _snack(
      context,
      ok
          ? 'Moved to ${status.toLowerCase().replaceAll('_', ' ')}'
          : (tasks.error ?? 'Could not change the status'),
      isError: !ok,
    );
  }

  static Future<void> reassign(BuildContext context, TaskModel task) async {
    if (_blocked(context, task.project)) {
      return;
    }

    final TaskProvider tasks = context.read<TaskProvider>();
    final UserProvider users = context.read<UserProvider>();
    final TeamProvider teams = context.read<TeamProvider>();
    final ProjectProvider projects = context.read<ProjectProvider>();

    final TeamModel? team = teams.byId(projects.byId(task.project)?.team);

    final List<UserModel> scoped = team == null || team.members.isEmpty
        ? users.allUsers
        : users.allUsers
            .where((UserModel u) =>
                team.members.contains(u.id) || team.teamLead == u.id)
            .toList();

    final int? picked = await pickAssignee(
      context,
      candidates: scoped.isEmpty ? users.allUsers : scoped,
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

    _snack(
      context,
      ok
          ? (userId == null ? 'Task unassigned' : 'Task reassigned')
          : (tasks.error ?? 'Could not reassign the task'),
      isError: !ok,
    );
  }

  static Future<void> edit(
    BuildContext context,
    TaskModel task, {
    List<ProjectModel>? selectableProjects,
  }) async {
    if (_blocked(context, task.project)) {
      return;
    }

    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TaskFormScreen(
          task: task,
          selectableProjects: selectableProjects,
        ),
      ),
    );

    if (saved == true && context.mounted) {
      _snack(context, 'Task updated');
    }
  }

  static Future<void> create(
    BuildContext context, {
    int? projectId,
    List<ProjectModel>? selectableProjects,
  }) async {
    if (projectId != null && _blocked(context, projectId)) {
      return;
    }

    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TaskFormScreen(
          initialProjectId: projectId,
          selectableProjects: selectableProjects,
        ),
      ),
    );

    if (saved == true && context.mounted) {
      _snack(context, 'Task created');
    }
  }

  static Future<void> delete(BuildContext context, TaskModel task) async {
    if (_blocked(context, task.project)) {
      return;
    }

    final TaskProvider tasks = context.read<TaskProvider>();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete this task?'),
          content: Text(
            '"${task.title}" and its comments, subtasks and history will be '
            'removed. This cannot be undone.',
          ),
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final bool ok = await tasks.deleteTask(task.id);

    if (!context.mounted) {
      return;
    }

    _snack(
      context,
      ok ? 'Task deleted' : (tasks.error ?? 'Could not delete the task'),
      isError: !ok,
    );
  }
}

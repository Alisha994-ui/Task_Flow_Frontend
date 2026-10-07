import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/project_constants.dart';
import '../../core/constants/task_constants.dart';
import '../../core/utils/project_rules.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/time_log_model.dart';
import '../../models/team_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/manager_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/time_log_provider.dart';
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

  /// Moves a task to another status.
  ///
  /// With [toStatus] the move happens straight away - that is the board
  /// dropping a card into a column. Without it, the person picks from a
  /// sheet.
  /// Keeps the timer honest when a task's status moves.
  ///
  ///   -> In progress : start the clock on this task
  ///   -> Completed   : stop it
  ///
  /// People forget the timer in both directions - they start work and
  /// never press start, then finish and leave it running overnight. The
  /// status is the thing they do remember to change, so the clock
  /// follows it.
  ///
  /// Only for the person doing the work. A manager moving somebody
  /// else's task to In progress must not start a clock against their
  /// own name.
  static Future<void> syncTimerForStatus(
    BuildContext context,
    TaskModel task,
    String status,
  ) async {
    final TimeLogProvider timers = context.read<TimeLogProvider>();
    final int? me = timers.currentUserId;

    if (me == null || task.assignee != me) {
      return;
    }

    try {
      final TimeLogModel? active = timers.activeLog;

      if (status == TaskStatus.inProgress) {
        if (active?.task == task.id) {
          return;
        }

        // One clock at a time: moving to a new task means the last one
        // is no longer what they are doing.
        if (active != null) {
          await timers.stop();
        }

        await timers.start(task.id);

        return;
      }

      if (status == TaskStatus.completed && active?.task == task.id) {
        await timers.stop();
      }
    } catch (_) {
      // The status change already went through. A timer that did not
      // follow is a small thing - never undo somebody's work over it.
    }
  }

  static Future<void> changeStatus(
    BuildContext context,
    TaskModel task, {
    String? toStatus,
  }) async {
    if (_blocked(context, task.project)) {
      return;
    }

    if (_completedAndLocked(context, task)) {
      return;
    }

    final TaskProvider tasks = context.read<TaskProvider>();
    final String? status =
        toStatus ?? await pickTaskStatus(context, task.status);

    if (status == null || status == task.status) {
      return;
    }

    final bool ok = await tasks.setStatus(task.id, status);

    if (!context.mounted) {
      return;
    }

    if (ok) {
      await syncTimerForStatus(context, task, status);

      if (!context.mounted) {
        return;
      }
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
    final bool teamHasNoMembers = team == null || team.members.isEmpty;

    final List<UserModel> scoped = teamHasNoMembers
        ? users.allUsers
        : users.allUsers
            .where((UserModel u) =>
                team.members.contains(u.id) || team.teamLead == u.id)
            .toList();

    final int? picked = await pickAssignee(
      context,
      candidates: scoped,
      current: task.assignee,
      scopeNote: teamHasNoMembers
          ? "This project's team has nobody in it yet - showing everyone."
          : null,
    );

    if (picked == null) {
      return;
    }

    final int? userId = picked == -1 ? null : picked;
    final bool ok = await tasks.assignTo(task.id, userId);

    // Belt and braces: assignTo() already refreshes this task from the
    // server's response, but the card must never sit showing the old
    // assignee until a manual pull-to-refresh - so also apply the
    // change locally right away.
    if (ok) {
      tasks.replaceLocally(
        task.copyWith(assignee: userId, clearAssignee: userId == null),
      );
    }

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

    // Otherwise, if a search field on the list behind this screen still
    // held focus, Flutter restores that focus (and the keyboard with it)
    // the moment this route pops back to it.
    FocusScope.of(context).unfocus();

    final bool? saved = await Navigator.of(context).push<bool>(
  MaterialPageRoute<bool>(
    builder: (_) => TaskFormScreen(
      task: task,
      selectableProjects: selectableProjects,
    ),
  ),
);

if (!context.mounted) {
  return;
}

// Prevent Flutter from restoring focus to the search field
// when returning from the edit screen.
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (context.mounted) {
    FocusManager.instance.primaryFocus?.unfocus();
  }
});

if (saved == true) {
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

    FocusScope.of(context).unfocus();

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

    // Defence in depth: even if some screen wires this up by mistake, a
    // Team Lead never gets to actually delete - only the confirm dialog
    // dismisses itself here, so this is never a dead end they can't
    // explain to themselves (they simply never reach it from the menu).
    if (context.read<AuthProvider>().role == UserRoles.teamLead) {
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

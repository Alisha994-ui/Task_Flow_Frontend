import '../core/utils/errors.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/project_constants.dart';
import '../core/constants/task_constants.dart';
import '../models/label_model.dart';
import '../models/task_model.dart';
import '../models/task_stats_model.dart';
import '../services/task_service.dart';

/// Which dashboard endpoint the counts come from. The backend has one per
/// role and they are not interchangeable.
enum TaskStatsScope { manager, teamLead, assignee }

/// How a status change is sent. Managers and leads PATCH the task itself;
/// an employee may only call `/tasks/{id}/status/` on their own task.
enum TaskStatusEndpoint { task, assigneeAction }

class TaskProvider extends ChangeNotifier {
  List<TaskModel> _all = <TaskModel>[];
  List<LabelModel> _labels = <LabelModel>[];
  TaskStatsModel _stats = TaskStatsModel.empty;
  TaskStatsScope _statsScope = TaskStatsScope.manager;
  TaskStatusEndpoint _statusEndpoint = TaskStatusEndpoint.task;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  String _search = '';
  String _statusFilter = kFilterAll;
  String _priorityFilter = kFilterAll;
  int? _projectFilter;
  int? _assigneeFilter;
  bool _overdueOnly = false;

  // --------------------------------------------------------------- getters

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get error => _error;

  TaskStatsModel get stats => _stats;

  TaskStatsScope get statsScope => _statsScope;

  /// Call this once when a panel opens, before [loadStats].
  void setStatsScope(TaskStatsScope scope) {
    _statsScope = scope;
  }

  TaskStatusEndpoint get statusEndpoint => _statusEndpoint;

  /// Call this once when a panel opens.
  void setStatusEndpoint(TaskStatusEndpoint endpoint) {
    _statusEndpoint = endpoint;
  }

  List<TaskModel> get allTasks => List<TaskModel>.unmodifiable(_all);

  List<LabelModel> get labels => List<LabelModel>.unmodifiable(_labels);

  String get search => _search;

  String get statusFilter => _statusFilter;

  String get priorityFilter => _priorityFilter;

  int? get projectFilter => _projectFilter;

  int? get assigneeFilter => _assigneeFilter;

  bool get overdueOnly => _overdueOnly;

  bool get hasFilters =>
      _search.trim().isNotEmpty ||
      _statusFilter != kFilterAll ||
      _priorityFilter != kFilterAll ||
      _projectFilter != null ||
      _assigneeFilter != null ||
      _overdueOnly;

  /// The filtered list the Tasks screen renders.
  List<TaskModel> get tasks {
    final String query = _search.trim().toLowerCase();

    final List<TaskModel> filtered = _all.where((TaskModel t) {
      if (_statusFilter != kFilterAll && t.status != _statusFilter) {
        return false;
      }

      if (_priorityFilter != kFilterAll && t.priority != _priorityFilter) {
        return false;
      }

      if (_projectFilter != null && t.project != _projectFilter) {
        return false;
      }

      if (_assigneeFilter != null && t.assignee != _assigneeFilter) {
        return false;
      }

      if (_overdueOnly && !t.isOverdue) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return t.title.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query);
    }).toList();

    filtered.sort(_byUrgency);

    return filtered;
  }

  /// Overdue first, then nearest due date, then priority.
  int _byUrgency(TaskModel a, TaskModel b) {
    if (a.isOverdue != b.isOverdue) {
      return a.isOverdue ? -1 : 1;
    }

    final DateTime aDue = a.dueDate ?? DateTime(2999);
    final DateTime bDue = b.dueDate ?? DateTime(2999);
    final int byDue = aDue.compareTo(bDue);

    if (byDue != 0) {
      return byDue;
    }

    return _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
  }

  int _priorityRank(String priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return 4;
      case TaskPriority.high:
        return 3;
      case TaskPriority.medium:
        return 2;
      default:
        return 1;
    }
  }

  /// The board's source list: every filter except status, because the
  /// columns are the statuses.
  List<TaskModel> get tasksForBoard {
    final String query = _search.trim().toLowerCase();

    final List<TaskModel> filtered = _all.where((TaskModel t) {
      if (_priorityFilter != kFilterAll && t.priority != _priorityFilter) {
        return false;
      }

      if (_projectFilter != null && t.project != _projectFilter) {
        return false;
      }

      if (_assigneeFilter != null && t.assignee != _assigneeFilter) {
        return false;
      }

      if (_overdueOnly && !t.isOverdue) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return t.title.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query);
    }).toList();

    filtered.sort(_byUrgency);

    return filtered;
  }

  /// Those tasks split into columns, one per status.
  Map<String, List<TaskModel>> get board {
    final Map<String, List<TaskModel>> columns = <String, List<TaskModel>>{
      for (final String status in TaskStatus.all) status: <TaskModel>[],
    };

    for (final TaskModel task in tasksForBoard) {
      columns[task.status]?.add(task);
    }

    return columns;
  }

  TaskModel? byId(int id) {
    for (final TaskModel task in _all) {
      if (task.id == id) {
        return task;
      }
    }

    return null;
  }

  List<TaskModel> forProject(int projectId) =>
      _all.where((TaskModel t) => t.project == projectId).toList()
        ..sort(_byUrgency);

  List<TaskModel> dueOn(DateTime day) =>
      _all.where((TaskModel t) => t.isDueOn(day)).toList()..sort(_byUrgency);

  List<TaskModel> get overdueTasks =>
      _all.where((TaskModel t) => t.isOverdue).toList()..sort(_byUrgency);

  List<TaskModel> get unassignedTasks =>
      _all.where((TaskModel t) => t.isUnassigned && !t.isCompleted).toList();

  /// How many tasks sit in each status, for the reports screen.
  Map<String, int> get countsByStatus {
    final Map<String, int> counts = <String, int>{
      for (final String status in TaskStatus.all) status: 0,
    };

    for (final TaskModel task in _all) {
      counts[task.status] = (counts[task.status] ?? 0) + 1;
    }

    return counts;
  }

  Map<String, int> get countsByPriority {
    final Map<String, int> counts = <String, int>{
      for (final String priority in TaskPriority.all) priority: 0,
    };

    for (final TaskModel task in _all) {
      counts[task.priority] = (counts[task.priority] ?? 0) + 1;
    }

    return counts;
  }

  /// Open task count per assignee id. Key -1 means unassigned.
  Map<int, int> get workload {
    final Map<int, int> load = <int, int>{};

    for (final TaskModel task in _all) {
      if (task.isCompleted) {
        continue;
      }

      final int key = task.assignee ?? -1;
      load[key] = (load[key] ?? 0) + 1;
    }

    return load;
  }

  int completedCountFor(int projectId) => _all
      .where((TaskModel t) => t.project == projectId && t.isCompleted)
      .length;

  // ------------------------------------------------------------- filters

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  void setStatusFilter(String value) {
    _statusFilter = value;
    notifyListeners();
  }

  void setPriorityFilter(String value) {
    _priorityFilter = value;
    notifyListeners();
  }

  void setProjectFilter(int? value) {
    _projectFilter = value;
    notifyListeners();
  }

  void setAssigneeFilter(int? value) {
    _assigneeFilter = value;
    notifyListeners();
  }

  void setOverdueOnly(bool value) {
    _overdueOnly = value;
    notifyListeners();
  }

  void clearFilters() {
    _search = '';
    _statusFilter = kFilterAll;
    _priorityFilter = kFilterAll;
    _projectFilter = null;
    _assigneeFilter = null;
    _overdueOnly = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------- load

  Future<void> load({bool silent = false}) async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;

    if (!silent) {
      _error = null;
      notifyListeners();
    }

    try {
      _all = await TaskService.getTasks();
      _error = null;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStats() async {
    try {
      if (_statsScope == TaskStatsScope.teamLead) {
        _stats = await TaskService.teamLeadDashboard();
      } else if (_statsScope == TaskStatsScope.assignee) {
        _stats = await TaskService.myDashboard();
      } else {
        _stats = await TaskService.managerDashboard();
      }

      notifyListeners();
    } catch (_) {
      // Counts are a nice-to-have; the task list already carries the data.
    }
  }

  Future<void> loadLabels() async {
    if (_labels.isNotEmpty) {
      return;
    }

    try {
      _labels = await TaskService.getLabels();
      notifyListeners();
    } catch (_) {
      // Labels are optional.
    }
  }

  Future<void> refresh() async {
    await Future.wait<void>(<Future<void>>[
      load(silent: _all.isNotEmpty),
      loadStats(),
    ]);
  }

  /// Loads once - used by screens that may open outside a panel shell.
  Future<void> ensureLoaded() async {
    if (_all.isEmpty && !_isLoading) {
      await load();
    }
  }

  // ---------------------------------------------------------------- CRUD

  Future<TaskModel?> createTask({
    required int project,
    required String title,
    String description = '',
    int? assignee,
    required String priority,
    required String status,
    String? startDate,
    String? dueDate,
    int progress = 0,
    List<int> labels = const <int>[],
  }) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final TaskModel created = await TaskService.createTask(
        project: project,
        title: title,
        description: description,
        assignee: assignee,
        priority: priority,
        status: status,
        startDate: startDate,
        dueDate: dueDate,
        progress: progress,
        labels: labels,
      );

      _all = <TaskModel>[created, ..._all];
      await loadStats();

      return created;
    } catch (e) {
      _error = friendlyError(e);

      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Partial update - used by the form and by the quick actions.
  Future<TaskModel?> patchTask(int id, Map<String, dynamic> changes) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final TaskModel updated = await TaskService.patchTask(id, changes);

      _all =
          _all.map((TaskModel t) => t.id == updated.id ? updated : t).toList();
      await loadStats();

      return updated;
    } catch (e) {
      _error = friendlyError(e);

      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> setStatus(int id, String status) async {
    if (_statusEndpoint == TaskStatusEndpoint.assigneeAction) {
      _isSaving = true;
      _error = null;
      notifyListeners();

      try {
        final TaskModel updated = await TaskService.updateOwnStatus(
          id: id,
          status: status,
        );

        _all = _all
            .map((TaskModel t) => t.id == updated.id ? updated : t)
            .toList();
        await loadStats();

        return true;
      } catch (e) {
        _error = friendlyError(e);

        return false;
      } finally {
        _isSaving = false;
        notifyListeners();
      }
    }

    final Map<String, dynamic> changes = <String, dynamic>{'status': status};

    // Keep progress honest when a task is opened or closed.
    if (status == TaskStatus.completed) {
      changes['progress'] = 100;
    } else if (status == TaskStatus.todo) {
      changes['progress'] = 0;
    }

    return await patchTask(id, changes) != null;
  }

  Future<bool> assignTo(int id, int? userId) async {
    return await patchTask(id, <String, dynamic>{'assignee': userId}) != null;
  }

  Future<bool> deleteTask(int id) async {
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await TaskService.deleteTask(id);
      _all = _all.where((TaskModel t) => t.id != id).toList();
      await loadStats();

      return true;
    } catch (e) {
      _error = friendlyError(e);

      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Keeps the list in sync when the detail screen saves something.
  void replaceLocally(TaskModel task) {
    _all = _all.map((TaskModel t) => t.id == task.id ? task : t).toList();
    notifyListeners();
  }

  /// Clears everything on sign out.
  void reset() {
    _all = <TaskModel>[];
    _labels = <LabelModel>[];
    _stats = TaskStatsModel.empty;
    _statsScope = TaskStatsScope.manager;
    _statusEndpoint = TaskStatusEndpoint.task;
    _isLoading = false;
    _isSaving = false;
    _error = null;
    clearFilters();
  }
}
